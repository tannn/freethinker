import Foundation

public actor DefaultAIService: AIServiceProtocol {
    public private(set) var currentModel: ModelOption

    public var isAvailable: Bool {
        adapter.availability() == .available
    }

    private let adapter: any FoundationModelsAdapterProtocol
    private let promptComposer: any ProvocationPromptComposing
    private let parser: any ProvocationResponseParsing
    private let clock: any AIServiceClock
    private let maxInitializationRetries: Int
    private let retryBackoffNanoseconds: UInt64

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

    public func setCurrentModel(_ model: ModelOption) {
        currentModel = model
    }

    public func preloadModel() async throws {
        try await adapter.preload(model: currentModel)
    }

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
            Logger.info(
                "Generated provocation requestId=\(request.id.uuidString) durationMs=\(Int(clock.now().timeIntervalSince(startedAt) * 1_000))",
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

private final class TimeoutTaskStore: @unchecked Sendable {
    private let lock = NSLock()
    private var operation: Task<Void, Never>?
    private var timeout: Task<Void, Never>?

    func set(operation: Task<Void, Never>, timeout: Task<Void, Never>) {
        lock.lock()
        self.operation = operation
        self.timeout = timeout
        lock.unlock()
    }

    func cancelOperation() {
        lock.lock()
        operation?.cancel()
        lock.unlock()
    }

    func cancelTimeout() {
        lock.lock()
        timeout?.cancel()
        lock.unlock()
    }

    func cancelAll() {
        lock.lock()
        operation?.cancel()
        timeout?.cancel()
        lock.unlock()
    }
}

public protocol AIServiceClock: Sendable {
    func now() -> Date
    func sleep(nanoseconds: UInt64) async throws
}

public struct SystemAIServiceClock: AIServiceClock {
    public init() {}

    public func now() -> Date {
        Date()
    }

    public func sleep(nanoseconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
