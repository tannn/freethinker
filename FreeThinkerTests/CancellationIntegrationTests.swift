import Foundation
import XCTest
@testable import FreeThinker

final class CancellationIntegrationTests: XCTestCase {
    func testCancellationDuringTextCapturePropagatesAndResetsState() async throws {
        let capture = CancellationTextCaptureService(
            delayNanoseconds: 700_000_000,
            capturedText: "Some selected text"
        )
        let ai = CancellationAIService(delayNanoseconds: 0)
        let recorder = CancellationCallbackRecorder()

        let orchestrator = makeOrchestrator(
            capture: capture,
            ai: ai,
            recorder: recorder
        )

        _ = await orchestrator.trigger(source: .hotkey, regenerateFromResponseID: nil)

        try await Task.sleep(nanoseconds: 120_000_000)
        await orchestrator.cancelCurrentGeneration(reason: .userClosedPanel)

        let observedCancel = await capture.observedCancellation
        let aiCallCount = await ai.generateCallCount
        XCTAssertTrue(observedCancel)
        XCTAssertEqual(aiCallCount, 0)

        let generatingTransitions = await recorder.generatingTransitions
        XCTAssertEqual(generatingTransitions, [true, false])

        let metrics = await orchestrator.currentMetrics()
        XCTAssertEqual(metrics.cancellationCount, 1)
    }

    func testCancellationDuringAIGenerationCancelsAndCleansUp() async throws {
        let capture = CancellationTextCaptureService(
            delayNanoseconds: 0,
            capturedText: "Prompt input"
        )
        let ai = CancellationAIService(delayNanoseconds: 700_000_000)
        let recorder = CancellationCallbackRecorder()

        let orchestrator = makeOrchestrator(
            capture: capture,
            ai: ai,
            recorder: recorder
        )

        _ = await orchestrator.trigger(source: .menu, regenerateFromResponseID: nil)

        try await waitUntil("AI started") {
            await ai.generateCallCount == 1
        }

        await orchestrator.cancelCurrentGeneration(reason: .regenerateRequested)

        let observedCancelAI = await ai.observedCancellation
        XCTAssertTrue(observedCancelAI)

        let generatingTransitions = await recorder.generatingTransitions
        XCTAssertEqual(generatingTransitions, [true, false])

        let metrics = await orchestrator.currentMetrics()
        XCTAssertEqual(metrics.cancellationCount, 1)
    }

    func testRegenerateCancelsInFlightWorkThenStartsNewRun() async throws {
        let capture = CancellationTextCaptureService(
            delayNanoseconds: 0,
            capturedText: "Prompt input"
        )
        let ai = CancellationAIService(delayNanoseconds: 500_000_000)
        let recorder = CancellationCallbackRecorder()

        let orchestrator = makeOrchestrator(
            capture: capture,
            ai: ai,
            recorder: recorder,
            debounceNanoseconds: 100
        )

        let first = await orchestrator.trigger(source: .hotkey, regenerateFromResponseID: nil)
        XCTAssertEqual(first, .started)

        try await waitUntil("AI started") {
            await ai.generateCallCount == 1
        }

        let second = await orchestrator.trigger(source: .regenerate, regenerateFromResponseID: UUID())
        XCTAssertEqual(second, .started)

        try await waitUntil("second generation") {
            await ai.generateCallCount == 2
        }

        let observedCancelSecond = await ai.observedCancellation
        XCTAssertTrue(observedCancelSecond)

        try await waitUntil("response from second generation") {
            await recorder.responseCount == 1
        }
    }
}

private extension CancellationIntegrationTests {
    func makeOrchestrator(
        capture: CancellationTextCaptureService,
        ai: CancellationAIService,
        recorder: CancellationCallbackRecorder,
        debounceNanoseconds: UInt64 = 300_000_000
    ) -> ProvocationOrchestrator {
        ProvocationOrchestrator(
            textCaptureService: capture,
            aiService: ai,
            settingsProvider: { AppSettings() },
            callbacks: ProvocationOrchestratorCallbacks(
                setGenerating: { value in
                    await recorder.recordGenerating(value)
                },
                presentLoading: { _ in
                    await recorder.recordLoading()
                },
                presentResponse: { _ in
                    await recorder.recordResponse()
                },
                presentError: { _ in
                    await recorder.recordError()
                },
                isPanelVisible: { true },
                notifyBackgroundMessage: { _ in
                    await recorder.recordNotification()
                }
            ),
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

private actor CancellationTextCaptureService: TextCaptureServiceProtocol {
    private let delayNanoseconds: UInt64
    private let capturedText: String

    private(set) var observedCancellation = false

    init(delayNanoseconds: UInt64, capturedText: String) {
        self.delayNanoseconds = delayNanoseconds
        self.capturedText = capturedText
    }

    func preflightPermission() -> TextCapturePermissionStatus {
        .granted
    }

    func captureSelectedText() async throws -> String {
        if delayNanoseconds > 0 {
            var remaining = delayNanoseconds
            while remaining > 0 {
                let step = min(remaining, 20_000_000)
                do {
                    try await Task.sleep(nanoseconds: step)
                } catch {
                    observedCancellation = true
                    throw CancellationError()
                }
                if Task.isCancelled {
                    observedCancellation = true
                    throw CancellationError()
                }
                remaining -= step
            }
        }

        return capturedText
    }
}

private actor CancellationAIService: AIServiceProtocol {
    private(set) var currentModel: ModelOption = .default
    private let delayNanoseconds: UInt64
    private(set) var generateCallCount = 0
    private(set) var observedCancellation = false

    nonisolated var isAvailable: Bool { true }

    init(delayNanoseconds: UInt64) {
        self.delayNanoseconds = delayNanoseconds
    }

    func setCurrentModel(_ model: ModelOption) {
        currentModel = model
    }

    func preloadModel() async throws {}

    func generateProvocation(request: ProvocationRequest, settings: AppSettings) async -> ProvocationResponse {
        generateCallCount += 1

        if delayNanoseconds > 0 {
            var remaining = delayNanoseconds
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

        return ProvocationResponse(
            requestId: request.id,
            originalText: request.selectedText,
            provocationType: request.provocationType,
            styleUsed: settings.provocationStylePreset,
            outcome: .success(
                content: ProvocationContent(
                    headline: "Counterpoint",
                    body: "A second run completed after cancellation.",
                    followUpQuestion: nil
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

private actor CancellationCallbackRecorder {
    private(set) var generatingTransitions: [Bool] = []
    private(set) var responseCount = 0

    func recordGenerating(_ value: Bool) {
        generatingTransitions.append(value)
    }

    func recordLoading() {}

    func recordResponse() {
        responseCount += 1
    }

    func recordError() {}

    func recordNotification() {}
}
