import Foundation

/// Identifies what initiated a provocation generation pipeline run.
public enum ProvocationTriggerSource: String, Sendable {
    /// The user pressed the global hotkey.
    case hotkey
    /// The user invoked generation via the menu bar item.
    case menu
    /// The user requested a new result for the same selected text.
    case regenerate
}

/// The decision made by the orchestrator when a trigger is received.
public enum ProvocationTriggerDecision: Equatable, Sendable {
    /// A new pipeline was started.
    case started
    /// The trigger was ignored because a generation was already in flight
    /// and the source was not `.regenerate`.
    case droppedInFlight
    /// The trigger arrived within the debounce window after the previous trigger.
    case debounced
}

/// The reason a running generation pipeline was cancelled.
public enum ProvocationCancellationReason: String, Sendable {
    /// The user dismissed or closed the floating panel.
    case userClosedPanel
    /// A regenerate trigger arrived, replacing the current run.
    case regenerateRequested
    /// The application is about to terminate.
    case appWillTerminate
}

/// Cumulative counters tracking orchestrator activity for the lifetime of the actor.
public struct ProvocationOrchestratorMetrics: Equatable, Sendable {
    /// Total number of triggers received (before any filtering).
    public var triggerReceived: Int = 0
    /// Triggers that successfully started a pipeline run.
    public var triggerStarted: Int = 0
    /// Triggers dropped because a generation was already in flight.
    public var droppedInFlight: Int = 0
    /// Triggers dropped because they arrived within the debounce window.
    public var droppedDebounced: Int = 0
    /// Number of pipeline runs cancelled for any reason.
    public var cancellationCount: Int = 0

    /// Creates a zero-valued metrics instance.
    public init() {}
}

/// Protocol for time sources used by the orchestrator for debounce calculations.
///
/// Abstracting the clock enables deterministic unit testing without real-time waits.
public protocol ProvocationOrchestratorClock: Sendable {
    /// Returns the current uptime in nanoseconds, used for debounce comparisons.
    func nowUptimeNanoseconds() -> UInt64
}

/// The default clock implementation backed by `DispatchTime`.
public struct SystemProvocationOrchestratorClock: ProvocationOrchestratorClock {
    /// Creates the system clock.
    public init() {}

    /// Returns the current system uptime in nanoseconds.
    public func nowUptimeNanoseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }
}

/// A collection of async closures the orchestrator calls to update UI state.
///
/// All closures are called from the orchestrator actor context, so each closure
/// must hop to the `@MainActor` internally if it modifies UI state.
public struct ProvocationOrchestratorCallbacks {
    /// Called when the generation in-progress state changes.
    ///
    /// - Parameter isGenerating: `true` when a pipeline run starts; `false` when it ends.
    public var setGenerating: (Bool) async -> Void

    /// Called to show the panel in a loading state with an optional text preview.
    ///
    /// - Parameter selectedTextPreview: A truncated preview of the selected text, or `nil`.
    public var presentLoading: (String?) async -> Void

    /// Called when the pipeline has produced a result (success or failure in response).
    ///
    /// - Parameter response: The completed ``ProvocationResponse``.
    public var presentResponse: (ProvocationResponse) async -> Void

    /// Called when an error should be presented in the floating panel.
    ///
    /// - Parameter presentation: The mapped error with message and suggested action.
    public var presentError: (ErrorPresentation) async -> Void

    /// Called to check whether the floating panel is currently visible.
    ///
    /// - Returns: `true` if the panel is visible, `false` otherwise.
    public var isPanelVisible: () async -> Bool

    /// Called to show a background notification when the panel is not visible.
    ///
    /// - Parameter message: The notification message string.
    public var notifyBackgroundMessage: (String) async -> Void

    /// Creates a callbacks struct with all closures explicitly provided.
    public init(
        setGenerating: @escaping (Bool) async -> Void,
        presentLoading: @escaping (String?) async -> Void,
        presentResponse: @escaping (ProvocationResponse) async -> Void,
        presentError: @escaping (ErrorPresentation) async -> Void,
        isPanelVisible: @escaping () async -> Bool,
        notifyBackgroundMessage: @escaping (String) async -> Void
    ) {
        self.setGenerating = setGenerating
        self.presentLoading = presentLoading
        self.presentResponse = presentResponse
        self.presentError = presentError
        self.isPanelVisible = isPanelVisible
        self.notifyBackgroundMessage = notifyBackgroundMessage
    }

    /// A no-op callbacks instance suitable for tests that don't need UI updates.
    public static let noOp = ProvocationOrchestratorCallbacks(
        setGenerating: { _ in },
        presentLoading: { _ in },
        presentResponse: { _ in },
        presentError: { _ in },
        isPanelVisible: { false },
        notifyBackgroundMessage: { _ in }
    )
}

/// Protocol defining the public interface for the provocation orchestrator.
///
/// Conforming types coordinate text capture, AI generation, and UI callback
/// invocation in response to user-initiated triggers. Actor isolation ensures
/// safe concurrent access to in-flight state.
public protocol ProvocationOrchestrating: Actor, Sendable {
    /// Attempts to start a new provocation pipeline for the given trigger.
    ///
    /// - Parameters:
    ///   - source: Where the trigger originated.
    ///   - regenerateFromResponseID: When `source` is `.regenerate`, the ID of the
    ///     previous response whose selected text should be reused.
    /// - Returns: A ``ProvocationTriggerDecision`` indicating whether the pipeline started.
    func trigger(
        source: ProvocationTriggerSource,
        regenerateFromResponseID: UUID?
    ) async -> ProvocationTriggerDecision

    /// Cancels any currently running generation pipeline.
    ///
    /// Awaits task completion before returning to ensure the pipeline is fully torn down.
    ///
    /// - Parameter reason: The semantic reason for cancellation, used in diagnostics.
    func cancelCurrentGeneration(reason: ProvocationCancellationReason) async

    /// Returns a snapshot of the orchestrator's cumulative activity metrics.
    func currentMetrics() -> ProvocationOrchestratorMetrics
}

/// Actor that coordinates the end-to-end provocation generation pipeline.
///
/// `ProvocationOrchestrator` sequences the following stages on each trigger:
/// 1. Permission preflight — verifies Accessibility permission.
/// 2. Text capture — reads the user's current selection.
/// 3. Panel loading — shows the floating panel in a loading state.
/// 4. Request composition — wraps the selection in a ``ProvocationRequest``.
/// 5. AI generation — sends the request to ``AIServiceProtocol``.
/// 6. Response presentation — delivers success or error via ``ProvocationOrchestratorCallbacks``.
///
/// At most one pipeline runs at a time. Concurrent triggers are either dropped or
/// replace the current run (for `.regenerate` triggers). A debounce window prevents
/// rapid repeated triggers from starting redundant pipelines.
public actor ProvocationOrchestrator: ProvocationOrchestrating {
    private let textCaptureService: any TextCaptureServiceProtocol
    private let aiService: any AIServiceProtocol
    private let settingsProvider: () async -> AppSettings
    private let errorMapper: ErrorPresentationMapping
    private let callbacks: ProvocationOrchestratorCallbacks
    private let diagnosticsLogger: (any DiagnosticsLogging)?
    private let clock: any ProvocationOrchestratorClock
    private let debounceNanoseconds: UInt64

    private var generationTask: Task<Void, Never>?
    private var pendingCancellationReason: ProvocationCancellationReason?
    private var lastAcceptedTriggerTime: UInt64?
    private var selectionByResponseID: [UUID: String] = [:]
    private var metrics = ProvocationOrchestratorMetrics()

    /// Creates a new orchestrator with the specified dependencies.
    ///
    /// - Parameters:
    ///   - textCaptureService: Service used to read the user's selected text.
    ///   - aiService: Service that performs AI generation.
    ///   - settingsProvider: Async closure returning the current ``AppSettings`` at the time of each pipeline run.
    ///   - errorMapper: Maps ``FreeThinkerError`` values to user-facing ``ErrorPresentation`` instances.
    ///   - callbacks: Closures the orchestrator calls to update UI state.
    ///   - diagnosticsLogger: Optional logger for recording pipeline stage events.
    ///   - clock: Time source for debounce calculations; defaults to the system uptime clock.
    ///   - debounceNanoseconds: Minimum nanoseconds between accepted triggers. Defaults to 300 ms.
    public init(
        textCaptureService: any TextCaptureServiceProtocol,
        aiService: any AIServiceProtocol,
        settingsProvider: @escaping () async -> AppSettings,
        errorMapper: ErrorPresentationMapping = ErrorPresentationMapper(),
        callbacks: ProvocationOrchestratorCallbacks = .noOp,
        diagnosticsLogger: (any DiagnosticsLogging)? = nil,
        clock: any ProvocationOrchestratorClock = SystemProvocationOrchestratorClock(),
        debounceNanoseconds: UInt64 = 300_000_000
    ) {
        self.textCaptureService = textCaptureService
        self.aiService = aiService
        self.settingsProvider = settingsProvider
        self.errorMapper = errorMapper
        self.callbacks = callbacks
        self.diagnosticsLogger = diagnosticsLogger
        self.clock = clock
        self.debounceNanoseconds = debounceNanoseconds
    }

    /// Attempts to start a new provocation pipeline run.
    ///
    /// If a generation is already in flight and `source` is `.regenerate`, the
    /// current run is cancelled and a new one starts using the cached selected text.
    /// For all other sources, an in-flight run causes the trigger to be dropped.
    ///
    /// - Parameters:
    ///   - source: The origin of the trigger (hotkey, menu, or regenerate).
    ///   - regenerateFromResponseID: For `.regenerate` triggers, the ID of the previous
    ///     response whose original selection should be reused.
    /// - Returns: ``ProvocationTriggerDecision/started`` if the pipeline launched,
    ///   ``ProvocationTriggerDecision/droppedInFlight`` if another run was active,
    ///   or ``ProvocationTriggerDecision/debounced`` if the trigger arrived too soon.
    public func trigger(
        source: ProvocationTriggerSource,
        regenerateFromResponseID: UUID? = nil
    ) async -> ProvocationTriggerDecision {
        metrics.triggerReceived += 1

        if let inFlight = generationTask {
            if source == .regenerate {
                pendingCancellationReason = .regenerateRequested
                inFlight.cancel()
                await inFlight.value
            } else {
                metrics.droppedInFlight += 1
                Logger.info("Dropped trigger source=\(source.rawValue) reason=in-flight", category: .orchestrator)
                return .droppedInFlight
            }
        }

        if source != .regenerate, isDebounced() {
            metrics.droppedDebounced += 1
            Logger.info("Dropped trigger source=\(source.rawValue) reason=debounced", category: .orchestrator)
            return .debounced
        }

        let triggerTimestamp = clock.nowUptimeNanoseconds()
        lastAcceptedTriggerTime = triggerTimestamp
        metrics.triggerStarted += 1

        generationTask = Task {
            await self.runPipelineTask(source: source, regenerateFromResponseID: regenerateFromResponseID)
        }

        return .started
    }

    /// Cancels the currently running generation task, if any, and waits for it to finish.
    ///
    /// After this method returns, the orchestrator is idle and ready to accept new triggers.
    ///
    /// - Parameter reason: The reason for cancellation, recorded in diagnostics and metrics.
    public func cancelCurrentGeneration(reason: ProvocationCancellationReason) async {
        guard let task = generationTask else {
            return
        }

        pendingCancellationReason = reason
        task.cancel()
        await task.value
    }

    /// Returns a snapshot of the orchestrator's cumulative activity counters.
    public func currentMetrics() -> ProvocationOrchestratorMetrics {
        metrics
    }
}

private extension ProvocationOrchestrator {
    func isDebounced() -> Bool {
        guard let lastAcceptedTriggerTime else {
            return false
        }

        let now = clock.nowUptimeNanoseconds()
        return now >= lastAcceptedTriggerTime && (now - lastAcceptedTriggerTime) < debounceNanoseconds
    }

    func runPipelineTask(
        source: ProvocationTriggerSource,
        regenerateFromResponseID: UUID?
    ) async {
        await callbacks.setGenerating(true)
        await runPipeline(source: source, regenerateFromResponseID: regenerateFromResponseID)
        generationTask = nil
        pendingCancellationReason = nil
        await callbacks.setGenerating(false)
    }

    func runPipeline(
        source: ProvocationTriggerSource,
        regenerateFromResponseID: UUID?
    ) async {
        do {
            Logger.info("Pipeline start source=\(source.rawValue)", category: .orchestrator)
            recordDiagnostic(
                stage: .permissionPreflight,
                category: .info,
                message: "Pipeline started",
                source: source
            )

            let selectedText: String
            if let cachedSelection = cachedSelectionForRegenerate(
                source: source,
                regenerateFromResponseID: regenerateFromResponseID
            ) {
                selectedText = cachedSelection
                recordDiagnostic(
                    stage: .textCapture,
                    category: .info,
                    message: "Selection reused from previous response",
                    source: source,
                    metadata: ["captured_character_count": "\(selectedText.count)"]
                )
            } else {
                try Task.checkCancellation()
                Logger.debug("Stage=permission-preflight", category: .orchestrator)
                guard await textCaptureService.preflightPermission() == .granted else {
                    await textCaptureService.requestAccessibilityPermissionPromptIfNeeded()
                    recordDiagnostic(
                        stage: .permissionPreflight,
                        category: .warning,
                        message: "Accessibility permission denied",
                        source: source
                    )
                    await present(error: .accessibilityPermissionDenied, source: source)
                    return
                }

                Logger.debug("Stage=text-capture", category: .orchestrator)
                selectedText = try await textCaptureService.captureSelectedText()
                recordDiagnostic(
                    stage: .textCapture,
                    category: .info,
                    message: "Selection captured",
                    source: source,
                    metadata: ["captured_character_count": "\(selectedText.count)"]
                )
            }

            Logger.debug("Stage=panel-loading", category: .orchestrator)
            await callbacks.presentLoading(selectedText)

            Logger.debug("Stage=request-compose", category: .orchestrator)
            let request = try ProvocationRequest(
                selectedText: selectedText,
                provocationType: .hiddenAssumptions,
                regenerateFromResponseID: regenerateFromResponseID
            )

            Logger.debug("Stage=ai-generate", category: .orchestrator)
            let settings = await settingsProvider().validated()
            recordDiagnostic(
                stage: .aiGeneration,
                category: .info,
                message: "AI generation started",
                source: source,
                metadata: ["model": settings.selectedModel.rawValue]
            )
            let response = await aiService.generateProvocation(request: request, settings: settings)

            if Task.isCancelled || pendingCancellationReason != nil {
                metrics.cancellationCount += 1
                let reason = pendingCancellationReason?.rawValue ?? "task-cancelled"
                Logger.info("Pipeline cancelled source=\(source.rawValue) reason=\(reason)", category: .orchestrator)
                recordDiagnostic(
                    stage: .aiGeneration,
                    category: .warning,
                    message: "Pipeline cancelled",
                    source: source,
                    metadata: ["reason": reason]
                )
                return
            }

            if let error = response.error {
                if error == .cancelled || Task.isCancelled {
                    metrics.cancellationCount += 1
                    let reason = pendingCancellationReason?.rawValue ?? "task-cancelled"
                    Logger.info("Pipeline cancelled source=\(source.rawValue) reason=\(reason)", category: .orchestrator)
                    recordDiagnostic(
                        stage: .aiGeneration,
                        category: .warning,
                        message: "Pipeline cancelled",
                        source: source,
                        metadata: ["reason": reason]
                    )
                    return
                }

                recordDiagnostic(
                    stage: .aiGeneration,
                    category: .error,
                    message: "AI generation failed",
                    source: source,
                    metadata: ["error_code": diagnosticErrorCode(for: error)]
                )
                await present(error: error, source: source)
                return
            }

            Logger.info(
                "Pipeline completed source=\(source.rawValue) requestId=\(request.id.uuidString)",
                category: .orchestrator
            )
            recordDiagnostic(
                stage: .responsePresentation,
                category: .info,
                message: "Response presented",
                source: source,
                metadata: ["request_id": request.id.uuidString]
            )
            if response.isSuccess {
                cacheSelection(selectedText, for: response.id)
            }
            await callbacks.presentResponse(response)
        } catch is CancellationError {
            metrics.cancellationCount += 1
            let reason = pendingCancellationReason?.rawValue ?? "task-cancelled"
            Logger.info("Pipeline cancelled source=\(source.rawValue) reason=\(reason)", category: .orchestrator)
            recordDiagnostic(
                stage: .aiGeneration,
                category: .warning,
                message: "Pipeline cancelled",
                source: source,
                metadata: ["reason": reason]
            )
        } catch {
            let mapped = mapUnhandled(error)
            recordDiagnostic(
                stage: .aiGeneration,
                category: .error,
                message: "Pipeline failed with unhandled error",
                source: source,
                metadata: ["error_code": diagnosticErrorCode(for: mapped)]
            )
            await present(error: mapped, source: source)
        }
    }

    func present(error: FreeThinkerError, source: ProvocationTriggerSource) async {
        let presentation = errorMapper.map(error: error, source: source)
        let panelVisible = await callbacks.isPanelVisible()

        if presentation.preferPanelPresentation || panelVisible {
            await callbacks.presentError(presentation)
            return
        }

        await callbacks.notifyBackgroundMessage(presentation.message)
    }

    func mapUnhandled(_ error: Error) -> FreeThinkerError {
        if let typed = error as? FreeThinkerError {
            return typed
        }
        if error is ProvocationRequest.ValidationError {
            return .noSelection
        }
        return .generationFailed
    }

    func recordDiagnostic(
        stage: DiagnosticStage,
        category: DiagnosticCategory,
        message: String,
        source: ProvocationTriggerSource,
        metadata: [String: String] = [:]
    ) {
        var payload = metadata
        payload["trigger_source"] = source.rawValue
        diagnosticsLogger?.record(
            stage: stage,
            category: category,
            message: message,
            metadata: payload
        )
    }

    func diagnosticErrorCode(for error: FreeThinkerError) -> String {
        switch error {
        case .accessibilityPermissionDenied:
            return "accessibility_permission_denied"
        case .noSelection:
            return "no_selection"
        case .hotkeyShortcutInvalid:
            return "hotkey_shortcut_invalid"
        case .hotkeyShortcutReserved:
            return "hotkey_shortcut_reserved"
        case .hotkeyRegistrationConflict:
            return "hotkey_registration_conflict"
        case .hotkeyRegistrationFailed:
            return "hotkey_registration_failed"
        case .timeout:
            return "timeout"
        case .cancelled:
            return "cancelled"
        case .modelUnavailable:
            return "model_unavailable"
        case .unsupportedOperatingSystem:
            return "unsupported_operating_system"
        case .unsupportedHardware:
            return "unsupported_hardware"
        case .frameworkUnavailable:
            return "framework_unavailable"
        case .transientModelFailure:
            return "transient_model_failure"
        case .generationFailed:
            return "generation_failed"
        case .invalidPrompt:
            return "invalid_prompt"
        case .invalidResponse:
            return "invalid_response"
        case .triggerDebounced:
            return "trigger_debounced"
        case .generationAlreadyInProgress:
            return "generation_in_progress"
        }
    }

    func cachedSelectionForRegenerate(
        source: ProvocationTriggerSource,
        regenerateFromResponseID: UUID?
    ) -> String? {
        guard source == .regenerate, let regenerateFromResponseID else {
            return nil
        }

        return selectionByResponseID[regenerateFromResponseID]
    }

    func cacheSelection(_ selectedText: String, for responseID: UUID) {
        selectionByResponseID = [responseID: selectedText]
    }
}
