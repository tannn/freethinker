import Foundation
import os

/// Concrete actor that implements ``AIServiceProtocol`` using the Foundation Models framework.
///
/// `DefaultAIService` composes prompts, delegates inference to a ``FoundationModelsAdapterProtocol``,
/// and parses raw output into ``ProvocationContent``. It wraps generation in a configurable timeout
/// and retries transient failures up to `maxInitializationRetries` times with exponential back-off.
///
/// Actor isolation guarantees that `currentModel` mutations are safe across concurrent callers.
public actor DefaultAIService: AIServiceProtocol {
    /// The model variant currently configured for generation.
    public private(set) var currentModel: ModelOption

    /// `true` when the underlying adapter reports ``FoundationModelAvailability/available``.
    public var isAvailable: Bool {
        adapter.availability() == .available
    }

    private let adapter: any FoundationModelsAdapterProtocol
    private let promptComposer: any ProvocationPromptComposing
    private let parser: any ProvocationResponseParsing
    private let clock: any AIServiceClock
    private let maxInitializationRetries: Int
    private let retryBackoffNanoseconds: UInt64

    /// Creates a `DefaultAIService` with the given dependencies.
    ///
    /// - Parameters:
    ///   - adapter: Foundation Models adapter used for inference. Defaults to `FoundationModelsAdapter()`.
    ///   - promptComposer: Composes prompt strings from requests and settings.
    ///   - parser: Parses raw model output into ``ProvocationContent``.
    ///   - currentModel: The initial model variant. Defaults to ``ModelOption/default``.
    ///   - maxInitializationRetries: How many times to retry a transient failure (0 = no retries). Defaults to 2.
    ///   - retryBackoffNanoseconds: Base back-off duration between retry attempts. Defaults to 150 ms.
    ///   - clock: Time source for timeout and retry scheduling.
    public init(
        adapter: any FoundationModelsAdapterProtocol = FoundationModelsAdapter(),
        promptComposer: any ProvocationPromptComposing = ProvocationPromptComposer(),
        parser: any ProvocationResponseParsing = ProvocationResponseParser(),
        currentModel: ModelOption = .default,
        maxInitializationRetries: Int = 2,
        retryBackoffNanoseconds: UInt64 = 150_000_000,
        clock: any AIServiceClock = SystemAIServiceClock()
    ) {
        self.adapter = adapter
        self.promptComposer = promptComposer
        self.parser = parser
        self.currentModel = currentModel
        self.maxInitializationRetries = max(0, maxInitializationRetries)
        self.retryBackoffNanoseconds = retryBackoffNanoseconds
        self.clock = clock
    }

    /// Updates the active model variant for future generation calls.
    ///
    /// - Parameter model: The new model to use.
    public func setCurrentModel(_ model: ModelOption) {
        currentModel = model
    }

    /// Warms up `currentModel` by delegating to the adapter's preload routine.
    ///
    /// - Throws: Errors propagated from the adapter if the model cannot be loaded.
    public func preloadModel() async throws {
        try await adapter.preload(model: currentModel)
    }

    /// Generates a provocation for the given request, applying timeout and retry logic.
    ///
    /// Settings are validated before use. `currentModel` is updated to match
    /// `settings.selectedModel` at the start of each call. The method never throws;
    /// errors are captured in the returned response's ``ProvocationOutcome/failure(error:)`` case.
    ///
    /// - Parameters:
    ///   - request: The provocation request with selected text and type.
    ///   - settings: App settings specifying model, timeout, and style.
    /// - Returns: A ``ProvocationResponse`` containing generated content or an error.
    public func generateProvocation(request: ProvocationRequest, settings: AppSettings) async -> ProvocationResponse {
        let normalizedSettings = settings.validated()
        let startedAt = clock.now()

        do {
            try Task.checkCancellation()

            currentModel = normalizedSettings.selectedModel
            let prompt = promptComposer.composePrompt(for: request, settings: normalizedSettings)
            let options = FoundationGenerationOptions(model: currentModel)
            let adapter = self.adapter
            let maxInitializationRetries = self.maxInitializationRetries
            let retryBackoffNanoseconds = self.retryBackoffNanoseconds
            let clock = self.clock

            let rawOutput = try await withTimeout(seconds: normalizedSettings.aiTimeoutSeconds) {
                try await Self.generateWithRetry(
                    prompt: prompt,
                    options: options,
                    adapter: adapter,
                    maxInitializationRetries: maxInitializationRetries,
                    retryBackoffNanoseconds: retryBackoffNanoseconds,
                    clock: clock
                )
            }

            let content = try parser.parse(rawOutput: rawOutput)
            let durationMs = Int(clock.now().timeIntervalSince(startedAt) * 1_000)
            Logger.info(
                "Generated provocation requestId=\(request.id.uuidString) durationMs=\(durationMs)",
                category: .aiService
            )

            return ProvocationResponse(
                requestId: request.id,
                originalText: request.selectedText,
                provocationType: request.provocationType,
                styleUsed: normalizedSettings.provocationStylePreset,
                outcome: .success(content: content),
                generationTime: clock.now().timeIntervalSince(startedAt),
                timestamp: clock.now()
            )
        } catch {
            let mapped = Self.mapError(error)
            Logger.warning(
                "Provocation generation failed requestId=\(request.id.uuidString) error=\(String(describing: mapped))",
                category: .aiService
            )
            return ProvocationResponse(
                requestId: request.id,
                originalText: request.selectedText,
                provocationType: request.provocationType,
                styleUsed: normalizedSettings.provocationStylePreset,
                outcome: .failure(error: mapped),
                generationTime: clock.now().timeIntervalSince(startedAt),
                timestamp: clock.now()
            )
        }
    }
}

private extension DefaultAIService {
    static func generateWithRetry(
        prompt: String,
        options: FoundationGenerationOptions,
        adapter: any FoundationModelsAdapterProtocol,
        maxInitializationRetries: Int,
        retryBackoffNanoseconds: UInt64,
        clock: any AIServiceClock
    ) async throws -> String {
        var attempt = 0
        var lastError: FreeThinkerError = .generationFailed

        while attempt <= maxInitializationRetries {
            attempt += 1
            do {
                return try await adapter.generate(prompt: prompt, options: options)
            } catch {
                let mapped = mapError(error)
                lastError = mapped

                let shouldRetry = mapped.isRetriable && attempt <= maxInitializationRetries
                if !shouldRetry {
                    throw mapped
                }

                Logger.warning(
                    "Retrying AI generation attempt=\(attempt) reason=\(String(describing: mapped))",
                    category: .aiService
                )
                try await clock.sleep(nanoseconds: retryBackoffNanoseconds * UInt64(attempt))
            }
        }

        throw lastError
    }

    func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let timeoutNanoseconds = UInt64(max(0, seconds) * 1_000_000_000)
        let timeoutClock = clock
        let taskStore = TimeoutTaskStore()

        defer {
            taskStore.cancelAll()
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
                let race = TimeoutRaceBox(continuation)

                let launchedOperationTask = Task.detached(priority: Task.currentPriority) {
                    do {
                        let value = try await operation()
                        await race.resume(.success(value))
                    } catch {
                        await race.resume(.failure(error))
                    }

                    taskStore.cancelTimeout()
                }

                let launchedTimeoutTask = Task.detached(priority: Task.currentPriority) {
                    do {
                        try await timeoutClock.sleep(nanoseconds: timeoutNanoseconds)
                    } catch {
                        return
                    }

                    launchedOperationTask.cancel()
                    await race.resume(.failure(FreeThinkerError.timeout))
                }

                taskStore.set(
                    operation: launchedOperationTask,
                    timeout: launchedTimeoutTask
                )
            }
        } onCancel: {
            taskStore.cancelAll()
        }
    }

    static func mapError(_ error: Error) -> FreeThinkerError {
        if let typed = error as? FreeThinkerError {
            return typed
        }
        if error is CancellationError {
            return .cancelled
        }
        return .generationFailed
    }
}

private actor TimeoutRaceBox<T> {
    private var continuation: CheckedContinuation<T, Error>?

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<T, Error>) {
        guard let continuation else {
            return
        }

        self.continuation = nil
        continuation.resume(with: result)
    }
}

private struct TimeoutTaskStore: Sendable {
    private struct State {
        var operation: Task<Void, Never>?
        var timeout: Task<Void, Never>?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func set(operation: Task<Void, Never>, timeout: Task<Void, Never>) {
        state.withLock { state in
            state.operation = operation
            state.timeout = timeout
        }
    }

    func cancelOperation() {
        state.withLock { state in
            state.operation?.cancel()
        }
    }

    func cancelTimeout() {
        state.withLock { state in
            state.timeout?.cancel()
        }
    }

    func cancelAll() {
        state.withLock { state in
            state.operation?.cancel()
            state.timeout?.cancel()
        }
    }
}

/// Protocol for the time source used by ``DefaultAIService``.
///
/// Abstracting the clock allows tests to inject a controlled time source
/// without requiring real delays.
public protocol AIServiceClock: Sendable {
    /// Returns the current wall-clock date.
    func now() -> Date

    /// Suspends the current task for the given number of nanoseconds.
    ///
    /// - Parameter nanoseconds: The sleep duration in nanoseconds.
    /// - Throws: `CancellationError` if the task is cancelled during sleep.
    func sleep(nanoseconds: UInt64) async throws
}

/// The default clock backed by `Date()` and `Task.sleep`.
public struct SystemAIServiceClock: AIServiceClock {
    /// Creates the system clock.
    public init() {}

    /// Returns the current date from the system clock.
    public func now() -> Date {
        Date()
    }

    /// Sleeps using `Task.sleep(nanoseconds:)`.
    ///
    /// - Parameter nanoseconds: The sleep duration in nanoseconds.
    /// - Throws: `CancellationError` if the task is cancelled.
    public func sleep(nanoseconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
