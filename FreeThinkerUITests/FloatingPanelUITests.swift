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

    func testFR002_CopyActionClosesPanelWhenDismissOnCopyEnabled_SC01() throws {
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

    func testFR002_CopyActionOnlyCopiesWhenDismissOnCopyDisabled_SC02() throws {
        var copiedPayloads: [String] = []
        var closeCount = 0

        let viewModel = FloatingPanelViewModel(
            isPinned: false,
            dismissOnCopy: false,
            timing: ImmediateTiming(),
            pasteboardWriter: { copiedPayloads.append($0) }
        )

        let response = try makeSuccessResponse()
        viewModel.onCloseRequested = {
            closeCount += 1
        }

        viewModel.setSuccess(response)
        viewModel.copyCurrentResult()

        XCTAssertEqual(copiedPayloads.count, 1)
        XCTAssertEqual(closeCount, 0)
        XCTAssertEqual(viewModel.copyFeedback, "Copied")
        XCTAssertFalse(viewModel.isRegenerating)
        guard case let .success(currentResponse) = viewModel.state else {
            return XCTFail("Expected success state after copy action")
        }
        XCTAssertEqual(currentResponse.id, response.id)
    }

    func testFR002_CopyActionDoesNotCloseWhenPinnedEvenIfDismissOnCopyEnabled_SC03() throws {
        var closeCount = 0
        let viewModel = FloatingPanelViewModel(
            isPinned: true,
            dismissOnCopy: true,
            timing: ImmediateTiming(),
            pasteboardWriter: { _ in }
        )
        viewModel.onCloseRequested = {
            closeCount += 1
        }

        viewModel.setSuccess(try makeSuccessResponse())
        viewModel.copyCurrentResult()

        XCTAssertEqual(closeCount, 0)
    }

    func testFR002_CopyFromResponseContentCopiesOnFirstInvocation_SC04() throws {
        var copiedPayloads: [String] = []
        var closeCount = 0
        let viewModel = FloatingPanelViewModel(
            isPinned: false,
            dismissOnCopy: true,
            timing: ImmediateTiming(),
            pasteboardWriter: { copiedPayloads.append($0) }
        )
        viewModel.onCloseRequested = {
            closeCount += 1
        }

        viewModel.setSuccess(try makeSuccessResponse())
        viewModel.copyFromResponseContent()

        XCTAssertEqual(copiedPayloads.count, 1)
        XCTAssertEqual(closeCount, 1)
        XCTAssertEqual(viewModel.copyFeedback, "Copied")
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
        XCTAssertEqual(FloatingPanelAccessibility.Identifier.copyTarget, "floating_panel.action.copy_target")
        XCTAssertEqual(FloatingPanelAccessibility.Identifier.regenerateButton, "floating_panel.action.regenerate")
        XCTAssertEqual(FloatingPanelAccessibility.Identifier.closeButton, "floating_panel.action.close")
        XCTAssertEqual(FloatingPanelAccessibility.Identifier.pinButton, "floating_panel.action.pin")
    }

    func testFloatingPanelWindowUsesExplicitKeyBehaviorForImmediateClickActions() {
        let window = FloatingPanelWindow()
        XCTAssertFalse(window.becomesKeyOnlyIfNeeded)
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
                    body: "\(headline). The argument treats velocity as the same thing as value creation.",
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
