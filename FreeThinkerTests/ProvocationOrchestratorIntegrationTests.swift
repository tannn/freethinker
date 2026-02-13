import Foundation
import XCTest
@testable import FreeThinker

final class ProvocationOrchestratorIntegrationTests: XCTestCase {
    func testHotkeyTriggerSuccessPathRunsFullPipeline() async throws {
        let textCapture = MockTextCaptureService(result: .success("Selected text from another app"))
        let aiService = MockAIService()
        let recorder = CallbackRecorder()

        let orchestrator = makeOrchestrator(
            textCaptureService: textCapture,
            aiService: aiService,
            recorder: recorder,
            debounceNanoseconds: 100
        )

        let decision = await orchestrator.trigger(source: .hotkey, regenerateFromResponseID: nil)
        XCTAssertEqual(decision, .started)

        try await waitUntil("response event") {
            await recorder.responseCount == 1
        }

        let preflightCount = await textCapture.preflightCallCount
        let captureCount = await textCapture.captureCallCount
        let aiCallCount = await aiService.generateCallCount
        XCTAssertEqual(preflightCount, 1)
        XCTAssertEqual(captureCount, 1)
        XCTAssertEqual(aiCallCount, 1)

        let events = await recorder.events
        XCTAssertTrue(events.contains(.loading))
        XCTAssertTrue(events.contains(.response))
    }

    func testMenuTriggerUsesSameOrchestratorPipeline() async throws {
        let textCapture = MockTextCaptureService(result: .success("Menu selected text"))
        let aiService = MockAIService()
        let recorder = CallbackRecorder()
        let orchestrator = makeOrchestrator(
            textCaptureService: textCapture,
            aiService: aiService,
            recorder: recorder,
            debounceNanoseconds: 100
        )

        let decision = await orchestrator.trigger(source: .menu, regenerateFromResponseID: nil)
        XCTAssertEqual(decision, .started)

        try await waitUntil("response event") {
            await recorder.responseCount == 1
        }

        let aiCallCount1 = await aiService.generateCallCount
        XCTAssertEqual(aiCallCount1, 1)
    }

    @MainActor
    func testMenuCoordinatorGenerateUsesSameOrchestratorPath() async throws {
        let textCapture = MockTextCaptureService(result: .success("Menu coordinator selection"))
        let aiService = MockAIService()
        let recorder = CallbackRecorder()
        let orchestrator = makeOrchestrator(
            textCaptureService: textCapture,
            aiService: aiService,
            recorder: recorder,
            debounceNanoseconds: 100
        )
        let appState = AppState(
            settings: AppSettings(),
            pinningStore: InMemoryPinningStore(),
            timing: ImmediateTiming(),
            pasteboardWriter: { _ in }
        )
        let coordinator = MenuBarCoordinator(
            appState: appState,
            orchestrator: orchestrator
        )

        coordinator.perform(.generate)

        try await waitUntil("response event from menu coordinator") {
            await recorder.responseCount == 1
        }
        let aiCallCount2 = await aiService.generateCallCount
        XCTAssertEqual(aiCallCount2, 1)
    }

    func testPermissionDeniedProducesMappedErrorWithoutGeneration() async throws {
        let textCapture = MockTextCaptureService(
            permission: .denied,
            result: .success("Unused")
        )
        let aiService = MockAIService()
        let recorder = CallbackRecorder()
        let orchestrator = makeOrchestrator(
            textCaptureService: textCapture,
            aiService: aiService,
            recorder: recorder
        )

        _ = await orchestrator.trigger(source: .hotkey, regenerateFromResponseID: nil)

        try await waitUntil("error event") {
            await recorder.errorMessages.count == 1
        }

        let aiCallCount3 = await aiService.generateCallCount
        let firstErrorMessage = await recorder.errorMessages.first
        XCTAssertEqual(aiCallCount3, 0)
        XCTAssertEqual(
            firstErrorMessage,
            "FreeThinker needs Accessibility access. Open Settings -> Privacy & Security -> Accessibility, then enable FreeThinker."
        )
    }

    func testNoSelectionProducesRetryGuidance() async throws {
        let textCapture = MockTextCaptureService(result: .failure(.noSelection))
        let aiService = MockAIService()
        let recorder = CallbackRecorder()
        let orchestrator = makeOrchestrator(
            textCaptureService: textCapture,
            aiService: aiService,
            recorder: recorder
        )

        _ = await orchestrator.trigger(source: .menu, regenerateFromResponseID: nil)

        try await waitUntil("error event") {
            await recorder.errorMessages.count == 1
        }

        let aiCallCount4 = await aiService.generateCallCount
        let secondErrorMessage = await recorder.errorMessages.first
        XCTAssertEqual(aiCallCount4, 0)
        XCTAssertEqual(
            secondErrorMessage,
            "Select some text in the active app, then trigger FreeThinker again."
        )
    }

    func testSingleFlightAndDebounceBehaviorUnderRapidTriggers() async throws {
        let textCapture = MockTextCaptureService(result: .success("Single flight input"))
        let aiService = MockAIService(generateDelayNanoseconds: 300_000_000)
        let recorder = CallbackRecorder()
        let clock = MutableOrchestratorClock(now: 1_000)

        let orchestrator = makeOrchestrator(
            textCaptureService: textCapture,
            aiService: aiService,
            recorder: recorder,
            clock: clock,
            debounceNanoseconds: 200
        )

        let first = await orchestrator.trigger(source: .hotkey, regenerateFromResponseID: nil)
        XCTAssertEqual(first, .started)

        let second = await orchestrator.trigger(source: .hotkey, regenerateFromResponseID: nil)
        XCTAssertEqual(second, .droppedInFlight)

        try await waitUntil("first response") {
            await recorder.responseCount == 1
        }

        clock.advance(to: 1_100)
        let third = await orchestrator.trigger(source: .menu, regenerateFromResponseID: nil)
        XCTAssertEqual(third, .debounced)

        clock.advance(to: 1_250)
        let fourth = await orchestrator.trigger(source: .menu, regenerateFromResponseID: nil)
        XCTAssertEqual(fourth, .started)

        try await waitUntil("second response") {
            await recorder.responseCount == 2
        }

        let metrics = await orchestrator.currentMetrics()
        XCTAssertEqual(metrics.triggerReceived, 4)
        XCTAssertEqual(metrics.triggerStarted, 2)
        XCTAssertEqual(metrics.droppedInFlight, 1)
        XCTAssertEqual(metrics.droppedDebounced, 1)
    }
}

private extension ProvocationOrchestratorIntegrationTests {
    func makeOrchestrator(
        textCaptureService: MockTextCaptureService,
        aiService: MockAIService,
        recorder: CallbackRecorder,
        clock: any ProvocationOrchestratorClock = SystemProvocationOrchestratorClock(),
        debounceNanoseconds: UInt64 = 300_000_000
    ) -> ProvocationOrchestrator {
        ProvocationOrchestrator(
            textCaptureService: textCaptureService,
            aiService: aiService,
            settingsProvider: { AppSettings() },
            callbacks: ProvocationOrchestratorCallbacks(
                setGenerating: { isGenerating in
                    await recorder.recordGenerating(isGenerating)
                },
                presentLoading: { _ in
                    await recorder.recordLoading()
                },
                presentResponse: { _ in
                    await recorder.recordResponse()
                },
                presentError: { presentation in
                    await recorder.recordError(message: presentation.message)
                },
                isPanelVisible: { false },
                notifyBackgroundMessage: { message in
                    await recorder.recordNotification(message: message)
                }
            ),
            clock: clock,
            debounceNanoseconds: debounceNanoseconds
        )
    }

    func waitUntil(
        _ label: String,
        timeoutNanoseconds: UInt64 = 1_500_000_000,
        pollNanoseconds: UInt64 = 20_000_000,
        condition: @escaping () async -> Bool
    ) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if await condition() {
                return
            }
            try await Task.sleep(nanoseconds: pollNanoseconds)
        }
        XCTFail("Timed out waiting for \(label)")
    }
}

private actor MockTextCaptureService: TextCaptureServiceProtocol {
    private(set) var preflightCallCount = 0
    private(set) var captureCallCount = 0
    private(set) var observedCancellation = false

    private let permission: TextCapturePermissionStatus
    private let result: Result<String, FreeThinkerError>
    private let captureDelayNanoseconds: UInt64

    init(
        permission: TextCapturePermissionStatus = .granted,
        result: Result<String, FreeThinkerError>,
        captureDelayNanoseconds: UInt64 = 0
    ) {
        self.permission = permission
        self.result = result
        self.captureDelayNanoseconds = captureDelayNanoseconds
    }

    func preflightPermission() -> TextCapturePermissionStatus {
        preflightCallCount += 1
        return permission
    }

    func setFallbackCaptureEnabled(_ isEnabled: Bool) {}

    func captureSelectedText() async throws -> String {
        captureCallCount += 1

        if captureDelayNanoseconds > 0 {
            var remaining = captureDelayNanoseconds
            while remaining > 0 {
                let step = min(remaining, 20_000_000)
                try await Task.sleep(nanoseconds: step)
                if Task.isCancelled {
                    observedCancellation = true
                    throw CancellationError()
                }
                remaining -= step
            }
        }

        switch result {
        case .success(let text):
            return text
        case .failure(let error):
            throw error
        }
    }
}

private actor MockAIService: AIServiceProtocol {
    private(set) var currentModel: ModelOption = .default
    private(set) var generateCallCount = 0
    private(set) var observedCancellation = false

    nonisolated var isAvailable: Bool { true }

    private let generateDelayNanoseconds: UInt64
    private let scriptedError: FreeThinkerError?

    init(
        generateDelayNanoseconds: UInt64 = 0,
        scriptedError: FreeThinkerError? = nil
    ) {
        self.generateDelayNanoseconds = generateDelayNanoseconds
        self.scriptedError = scriptedError
    }

    func setCurrentModel(_ model: ModelOption) {
        currentModel = model
    }

    func preloadModel() async throws {}

    func generateProvocation(request: ProvocationRequest, settings: AppSettings) async -> ProvocationResponse {
        generateCallCount += 1

        if generateDelayNanoseconds > 0 {
            var remaining = generateDelayNanoseconds
            while remaining > 0 {
                let step = min(remaining, 20_000_000)
                do {
                    try await Task.sleep(nanoseconds: step)
                } catch {
                    observedCancellation = true
                    return Self.cancelledResponse(for: request)
                }
                if Task.isCancelled {
                    observedCancellation = true
                    return Self.cancelledResponse(for: request)
                }
                remaining -= step
            }
        }

        if let scriptedError {
            return ProvocationResponse(
                requestId: request.id,
                originalText: request.selectedText,
                provocationType: request.provocationType,
                styleUsed: settings.provocationStylePreset,
                outcome: .failure(error: scriptedError),
                generationTime: 0.1
            )
        }

        return ProvocationResponse(
            requestId: request.id,
            originalText: request.selectedText,
            provocationType: request.provocationType,
            styleUsed: settings.provocationStylePreset,
            outcome: .success(
                content: ProvocationContent(
                    headline: "Challenge the premise",
                    body: "This argument assumes static incentives and no adaptation.",
                    followUpQuestion: "What changes if incentives shift?"
                )
            ),
            generationTime: 0.1
        )
    }

    nonisolated private static func cancelledResponse(for request: ProvocationRequest) -> ProvocationResponse {
        ProvocationResponse(
            requestId: request.id,
            originalText: request.selectedText,
            provocationType: request.provocationType,
            styleUsed: .socratic,
            outcome: .failure(error: .cancelled),
            generationTime: 0.0
        )
    }
}

private actor CallbackRecorder {
    enum Event: Equatable {
        case generating(Bool)
        case loading
        case response
        case error
        case notification
    }

    private(set) var events: [Event] = []
    private(set) var errorMessages: [String] = []

    var responseCount: Int {
        events.filter { $0 == .response }.count
    }

    func recordGenerating(_ isGenerating: Bool) {
        events.append(.generating(isGenerating))
    }

    func recordLoading() {
        events.append(.loading)
    }

    func recordResponse() {
        events.append(.response)
    }

    func recordError(message: String) {
        events.append(.error)
        errorMessages.append(message)
    }

    func recordNotification(message: String) {
        events.append(.notification)
        errorMessages.append(message)
    }
}

private final class MutableOrchestratorClock: ProvocationOrchestratorClock, @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64

    init(now: UInt64) {
        self.value = now
    }

    func nowUptimeNanoseconds() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func advance(to newValue: UInt64) {
        lock.lock()
        value = newValue
        lock.unlock()
    }
}

private struct ImmediateTiming: FloatingPanelTiming {
    func sleep(nanoseconds: UInt64) async throws {}
}

private final class InMemoryPinningStore: PanelPinningStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func loadPinnedState() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func savePinnedState(_ isPinned: Bool) {
        lock.lock()
        value = isPinned
        lock.unlock()
    }
}
