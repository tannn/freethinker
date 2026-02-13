import Foundation

public enum ProvocationTriggerSource: String, Sendable {
    case hotkey
    case menu
    case regenerate
}

public enum ProvocationTriggerDecision: Equatable, Sendable {
    case started
    case droppedInFlight
    case debounced
}

public enum ProvocationCancellationReason: String, Sendable {
    case userClosedPanel
    case regenerateRequested
    case appWillTerminate
}

public struct ProvocationOrchestratorMetrics: Equatable, Sendable {
    public var triggerReceived: Int = 0
    public var triggerStarted: Int = 0
    public var droppedInFlight: Int = 0
    public var droppedDebounced: Int = 0
    public var cancellationCount: Int = 0

    public init() {}
}

public protocol ProvocationOrchestratorClock: Sendable {
    func nowUptimeNanoseconds() -> UInt64
}

public struct SystemProvocationOrchestratorClock: ProvocationOrchestratorClock {
    public init() {}

    public func nowUptimeNanoseconds() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }
}

public struct ProvocationOrchestratorCallbacks {
    public var setGenerating: (Bool) async -> Void
    public var presentLoading: (String?) async -> Void
    public var presentResponse: (ProvocationResponse) async -> Void
    public var presentError: (ErrorPresentation) async -> Void
    public var isPanelVisible: () async -> Bool
    public var notifyBackgroundMessage: (String) async -> Void

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

    public static let noOp = ProvocationOrchestratorCallbacks(
        setGenerating: { _ in },
        presentLoading: { _ in },
        presentResponse: { _ in },
        presentError: { _ in },
        isPanelVisible: { false },
        notifyBackgroundMessage: { _ in }
    )
}

public protocol ProvocationOrchestrating: Actor, Sendable {
    func trigger(
        source: ProvocationTriggerSource,
        regenerateFromResponseID: UUID?
    ) async -> ProvocationTriggerDecision

    func cancelCurrentGeneration(reason: ProvocationCancellationReason) async
    func currentMetrics() -> ProvocationOrchestratorMetrics
}

public actor ProvocationOrchestrator: ProvocationOrchestrating {
    private let textCaptureService: any TextCaptureServiceProtocol
    private let aiService: any AIServiceProtocol
    private let settingsProvider: () async -> AppSettings
    private let errorMapper: ErrorPresentationMapping
    private let callbacks: ProvocationOrchestratorCallbacks
    private let clock: any ProvocationOrchestratorClock
    private let debounceNanoseconds: UInt64

    private var generationTask: Task<Void, Never>?
    private var pendingCancellationReason: ProvocationCancellationReason?
    private var lastAcceptedTriggerTime: UInt64?
    private var metrics = ProvocationOrchestratorMetrics()

    public init(
        textCaptureService: any TextCaptureServiceProtocol,
        aiService: any AIServiceProtocol,
        settingsProvider: @escaping () async -> AppSettings,
        errorMapper: ErrorPresentationMapping = ErrorPresentationMapper(),
        callbacks: ProvocationOrchestratorCallbacks = .noOp,
        clock: any ProvocationOrchestratorClock = SystemProvocationOrchestratorClock(),
        debounceNanoseconds: UInt64 = 300_000_000
    ) {
        self.textCaptureService = textCaptureService
        self.aiService = aiService
        self.settingsProvider = settingsProvider
        self.errorMapper = errorMapper
        self.callbacks = callbacks
        self.clock = clock
        self.debounceNanoseconds = debounceNanoseconds
    }

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

    public func cancelCurrentGeneration(reason: ProvocationCancellationReason) async {
        guard let task = generationTask else {
            return
        }

        pendingCancellationReason = reason
        task.cancel()
        await task.value
    }

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

            try Task.checkCancellation()
            Logger.debug("Stage=permission-preflight", category: .orchestrator)
            guard await textCaptureService.preflightPermission() == .granted else {
                await present(error: .accessibilityPermissionDenied, source: source)
                return
            }

            Logger.debug("Stage=text-capture", category: .orchestrator)
            let selectedText = try await textCaptureService.captureSelectedText()

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
            let response = await aiService.generateProvocation(request: request, settings: settings)

            if let error = response.error {
                if error == .cancelled {
                    metrics.cancellationCount += 1
                    let reason = pendingCancellationReason?.rawValue ?? "service-cancelled"
                    Logger.info("Pipeline cancelled source=\(source.rawValue) reason=\(reason)", category: .orchestrator)
                    return
                }

                await present(error: error, source: source)
                return
            }

            Logger.info(
                "Pipeline completed source=\(source.rawValue) requestId=\(request.id.uuidString)",
                category: .orchestrator
            )
            await callbacks.presentResponse(response)
        } catch is CancellationError {
            metrics.cancellationCount += 1
            let reason = pendingCancellationReason?.rawValue ?? "task-cancelled"
            Logger.info("Pipeline cancelled source=\(source.rawValue) reason=\(reason)", category: .orchestrator)
        } catch {
            let mapped = mapUnhandled(error)
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
}
