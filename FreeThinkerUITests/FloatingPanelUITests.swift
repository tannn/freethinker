import Foundation
import XCTest
@testable import FreeThinker

@MainActor
final class FloatingPanelUITests: XCTestCase {
    func testLoadingToSuccessTransitionAfterGeneration() throws {
        let appState = AppState(
            settings: AppSettings(dismissOnCopy: false),
            pinningStore: InMemoryPinningStore(),
            timing: ImmediateTiming(),
            pasteboardWriter: { _ in }
        )

        appState.presentLoading(selectedText: "Automation improves outcomes.")
        guard case .loading = appState.panelViewModel.state else {
            return XCTFail("Expected loading state")
        }

        let response = try makeSuccessResponse()
        appState.present(response: response)

        guard case let .success(current) = appState.panelViewModel.state else {
            return XCTFail("Expected success state")
        }
        XCTAssertEqual(current.id, response.id)
    }

    func testErrorStateRetryPathInvokesRegenerateHandler() async throws {
        let appState = AppState(
            settings: AppSettings(dismissOnCopy: false),
            pinningStore: InMemoryPinningStore(),
            timing: ImmediateTiming(),
            pasteboardWriter: { _ in }
        )

        let expectedResponse = try makeSuccessResponse(headline: "Second pass")
        var regenerateCallCount = 0

        appState.onRegenerateRequested = { _ in
            regenerateCallCount += 1
            appState.presentLoading(selectedText: nil)
            appState.present(response: expectedResponse)
        }

        appState.presentError(.timeout)
        guard case .error = appState.panelViewModel.state else {
            return XCTFail("Expected error state")
        }

        appState.panelViewModel.requestRegenerate()
        await Task.yield()

        XCTAssertEqual(regenerateCallCount, 1)
        guard case let .success(response) = appState.panelViewModel.state else {
            return XCTFail("Expected success state after retry")
        }
        XCTAssertEqual(response.id, expectedResponse.id)
    }

    func testCopyAndCloseActions() throws {
        var copiedText: String?
        var closeCount = 0

        let viewModel = FloatingPanelViewModel(
            isPinned: false,
            dismissOnCopy: true,
            timing: ImmediateTiming(),
            pasteboardWriter: { copiedText = $0 }
        )

        viewModel.onCloseRequested = {
            closeCount += 1
        }

        viewModel.setSuccess(try makeSuccessResponse())
        viewModel.copyCurrentResult()

        XCTAssertNotNil(copiedText)
        XCTAssertTrue(copiedText?.contains("Question the certainty") ?? false)
        XCTAssertEqual(closeCount, 1)
    }

    func testPinnedPanelPersistsAcrossTriggerCycles() {
        let pinningStore = InMemoryPinningStore()

        let firstCycle = AppState(
            settings: AppSettings(dismissOnCopy: false),
            pinningStore: pinningStore,
            timing: ImmediateTiming(),
            pasteboardWriter: { _ in }
        )
        XCTAssertFalse(firstCycle.panelViewModel.isPinned)

        firstCycle.panelViewModel.togglePin()
        XCTAssertTrue(firstCycle.panelViewModel.isPinned)

        let secondCycle = AppState(
            settings: AppSettings(dismissOnCopy: false),
            pinningStore: pinningStore,
            timing: ImmediateTiming(),
            pasteboardWriter: { _ in }
        )
        XCTAssertTrue(secondCycle.panelViewModel.isPinned)
    }

    func testAccessibilityIdentifiersRemainStable() {
        XCTAssertEqual(FloatingPanelAccessibility.Identifier.panel, "floating_panel.root")
        XCTAssertEqual(FloatingPanelAccessibility.Identifier.copyButton, "floating_panel.action.copy")
        XCTAssertEqual(FloatingPanelAccessibility.Identifier.regenerateButton, "floating_panel.action.regenerate")
        XCTAssertEqual(FloatingPanelAccessibility.Identifier.closeButton, "floating_panel.action.close")
        XCTAssertEqual(FloatingPanelAccessibility.Identifier.pinButton, "floating_panel.action.pin")
    }
}

private extension FloatingPanelUITests {
    func makeSuccessResponse(headline: String = "Question the certainty") throws -> ProvocationResponse {
        let request = try ProvocationRequest(
            selectedText: "We should always optimize for speed.",
            provocationType: .hiddenAssumptions
        )

        return ProvocationResponse(
            requestId: request.id,
            originalText: request.selectedText,
            provocationType: request.provocationType,
            styleUsed: .socratic,
            outcome: .success(
                content: ProvocationContent(
                    headline: headline,
                    body: "The argument treats velocity as the same thing as value creation.",
                    followUpQuestion: "What quality constraints are being traded away?"
                )
            ),
            generationTime: 0.2
        )
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
