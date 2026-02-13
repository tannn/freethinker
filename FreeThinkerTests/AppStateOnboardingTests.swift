import Foundation
import XCTest
@testable import FreeThinker

@MainActor
final class AppStateOnboardingTests: XCTestCase {
    func testFirstLaunchPresentsOnboarding() {
        let state = AppState(
            settings: AppSettings(hasSeenOnboarding: false),
            pinningStore: InMemoryPinningStore(),
            timing: ImmediateTiming(),
            pasteboardWriter: { _ in }
        )

        XCTAssertTrue(state.isOnboardingPresented)
        XCTAssertFalse(state.settings.hasSeenOnboarding)
    }

    func testDismissOnboardingMarksSeen() {
        let state = AppState(
            settings: AppSettings(hasSeenOnboarding: false),
            pinningStore: InMemoryPinningStore(),
            timing: ImmediateTiming(),
            pasteboardWriter: { _ in }
        )

        state.dismissOnboarding(markSeen: true)

        XCTAssertFalse(state.isOnboardingPresented)
        XCTAssertTrue(state.settings.hasSeenOnboarding)
    }

    func testCompleteOnboardingPersistsCompletionAndHotkeyAwareness() {
        let state = AppState(
            settings: AppSettings(hasSeenOnboarding: false, onboardingCompleted: false),
            pinningStore: InMemoryPinningStore(),
            timing: ImmediateTiming(),
            pasteboardWriter: { _ in }
        )

        state.setHotkeyAwarenessConfirmed(true)
        state.updateOnboardingSystemReadiness(
            accessibilityGranted: true,
            modelAvailability: .available
        )
        state.completeOnboarding()

        XCTAssertFalse(state.isOnboardingPresented)
        XCTAssertTrue(state.settings.hasSeenOnboarding)
        XCTAssertTrue(state.settings.onboardingCompleted)
        XCTAssertTrue(state.settings.hotkeyAwarenessConfirmed)
    }

    func testPresentOnboardingCanReopenGuide() {
        let state = AppState(
            settings: AppSettings(hasSeenOnboarding: true),
            pinningStore: InMemoryPinningStore(),
            timing: ImmediateTiming(),
            pasteboardWriter: { _ in }
        )

        XCTAssertFalse(state.isOnboardingPresented)

        state.presentOnboarding()

        XCTAssertTrue(state.isOnboardingPresented)
    }
}

private struct ImmediateTiming: FloatingPanelTiming {
    func sleep(nanoseconds: UInt64) async throws {}
}

private final class InMemoryPinningStore: PanelPinningStore, @unchecked Sendable {
    private var value = false

    func loadPinnedState() -> Bool {
        value
    }

    func savePinnedState(_ isPinned: Bool) {
        value = isPinned
    }
}
