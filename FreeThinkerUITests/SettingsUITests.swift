import Foundation
import XCTest
@testable import FreeThinker

@MainActor
final class SettingsUITests: XCTestCase {
    func testSettingsMutationsReflectImmediatelyAndPersist() async throws {
        let recorder = PersistenceRecorder()
        let appState = makeAppState()
        appState.onSettingsPersistRequested = { settings in
            await recorder.record(settings)
        }

        await appState.setDismissOnCopy(false)
        await appState.setAutoDismissSeconds(9)
        await appState.setFallbackCaptureEnabled(false)
        await appState.setAutomaticallyCheckForUpdates(false)
        await Task.yield()

        XCTAssertFalse(appState.settings.dismissOnCopy)
        XCTAssertEqual(appState.settings.autoDismissSeconds, 9)
        XCTAssertFalse(appState.settings.fallbackCaptureEnabled)
        XCTAssertFalse(appState.settings.automaticallyCheckForUpdates)

        let persisted = await recorder.lastSaved
        XCTAssertEqual(persisted?.dismissOnCopy, false)
        XCTAssertEqual(persisted?.autoDismissSeconds, 9)
        XCTAssertEqual(persisted?.fallbackCaptureEnabled, false)
        XCTAssertEqual(persisted?.automaticallyCheckForUpdates, false)
    }

    func testPersistenceKeepsLatestSettingsWhenEarlierSaveFinishesLast() async throws {
        let recorder = ControlledPersistenceRecorder()
        let appState = makeAppState()
        appState.onSettingsPersistRequested = { settings in
            await recorder.persist(settings)
        }

        await appState.setDismissOnCopy(false)
        await recorder.waitForFirstSaveToStart()

        await appState.setDismissOnCopy(true)
        try await Task.sleep(nanoseconds: 30_000_000)
        await recorder.allowFirstSaveToFinish()
        try await Task.sleep(nanoseconds: 80_000_000)

        let saveCount = await recorder.saveCount()
        let lastSaved = await recorder.lastSaved()

        XCTAssertEqual(saveCount, 2)
        XCTAssertEqual(lastSaved?.dismissOnCopy, true)
        XCTAssertFalse(appState.isPersistingSettings)
    }

    func testPinBehaviorPersistsAcrossRelaunchSimulation() async {
        let pinningStore = InMemoryPinningStore()
        let firstLaunch = makeAppState(pinningStore: pinningStore)
        await firstLaunch.setPanelPinned(true)
        XCTAssertTrue(firstLaunch.panelViewModel.isPinned)

        let secondLaunch = makeAppState(pinningStore: pinningStore)
        XCTAssertTrue(secondLaunch.panelViewModel.isPinned)
    }

    func testSettingsPersistAcrossRelaunchSimulation() async throws {
        let storage = InMemorySettingsService()

        let firstLaunch = makeAppState(settings: storage.loadSettings())
        firstLaunch.onSettingsPersistRequested = { settings in
            try storage.saveSettings(settings)
        }

        await firstLaunch.setProvocationStylePreset(.systemsThinking)
        await firstLaunch.setCustomStyleInstructions("Challenge hidden second-order effects.")
        await firstLaunch.setAppUpdateChannel(.beta)
        await Task.yield()

        let secondLaunch = makeAppState(settings: storage.loadSettings())
        XCTAssertEqual(secondLaunch.settings.provocationStylePreset, .systemsThinking)
        XCTAssertEqual(secondLaunch.settings.customStyleInstructions, "Challenge hidden second-order effects.")
        XCTAssertEqual(secondLaunch.settings.appUpdateChannel, .beta)
    }

    func testCustomInstructionValidationBoundaries() async throws {
        let appState = makeAppState()

        let oversize = String(repeating: "X", count: AppSettings.maxCustomInstructionLength + 40) + "\0"
        await appState.setCustomStyleInstructions(oversize)

        XCTAssertEqual(appState.settings.customStyleInstructions.count, AppSettings.maxCustomInstructionLength)
        XCTAssertFalse(appState.settings.customStyleInstructions.contains("\0"))
    }

    func testGuardrailPreventsDisablingBothHotkeyAndMenuBar() async {
        let appState = makeAppState()

        await appState.setHotkeyEnabled(false)
        await appState.setShowMenuBarIcon(false)

        XCTAssertFalse(appState.settings.hotkeyEnabled)
        XCTAssertTrue(appState.settings.showMenuBarIcon)
        XCTAssertEqual(
            appState.settingsValidationMessage,
            "Keep either Global Hotkey or Menu Bar Icon enabled so FreeThinker stays reachable."
        )
    }

    func testLaunchAtLoginFailureShowsActionableFeedback() async {
        let appState = makeAppState()
        appState.onLaunchAtLoginChangeRequested = { _ in
            throw LaunchAtLoginError.unsupported
        }

        await appState.setLaunchAtLoginEnabled(true)

        XCTAssertFalse(appState.settings.launchAtLogin)
        XCTAssertEqual(
            appState.settingsSaveErrorMessage,
            "Could not update Launch at Login. Launch at Login is not supported on this macOS configuration."
        )
    }

    func testLaunchAtLoginRetryClearsErrorFeedback() async {
        let appState = makeAppState()
        appState.onLaunchAtLoginChangeRequested = { _ in
            throw LaunchAtLoginError.failed("Temporary launch service issue.")
        }

        await appState.setLaunchAtLoginEnabled(true)
        XCTAssertEqual(
            appState.settingsSaveErrorMessage,
            "Could not update Launch at Login. Temporary launch service issue."
        )

        appState.onLaunchAtLoginChangeRequested = { _ in }
        await appState.setLaunchAtLoginEnabled(true)

        XCTAssertTrue(appState.settings.launchAtLogin)
        XCTAssertNil(appState.settingsSaveErrorMessage)
    }

    func testSettingsChangesAffectPromptStyleComposition() async throws {
        let appState = makeAppState()
        await appState.setProvocationStylePreset(.contrarian)
        await appState.setCustomStyleInstructions("Prioritize assumptions about incentives.")

        let request = try ProvocationRequest(
            selectedText: "A single metric can represent product quality.",
            provocationType: .hiddenAssumptions
        )

        let prompt = ProvocationPromptComposer().composePrompt(for: request, settings: appState.settings)
        XCTAssertTrue(prompt.contains("Take a rigorous contrary angle."))
        XCTAssertTrue(prompt.contains("Prioritize assumptions about incentives."))
    }

    func testSettingsAccessibilityIdentifiersRemainStable() {
        XCTAssertEqual(SettingsAccessibility.Identifier.root, "settings.root")
        XCTAssertEqual(SettingsAccessibility.Identifier.sectionGeneral, "settings.section.general")
        XCTAssertEqual(SettingsAccessibility.Identifier.sectionProvocation, "settings.section.provocation")
        XCTAssertEqual(SettingsAccessibility.Identifier.generalPinPanelToggle, "settings.general.pin_panel")
        XCTAssertEqual(SettingsAccessibility.Identifier.generalLaunchAtLoginToggle, "settings.general.launch_at_login")
        XCTAssertEqual(SettingsAccessibility.Identifier.provocationCustomInstructionEditor, "settings.provocation.custom_instruction")
    }
}

private extension SettingsUITests {
    func makeAppState(
        settings: AppSettings = AppSettings(),
        pinningStore: any PanelPinningStore = InMemoryPinningStore()
    ) -> AppState {
        AppState(
            settings: settings,
            pinningStore: pinningStore,
            timing: ImmediateTiming(),
            pasteboardWriter: { _ in }
        )
    }
}

private actor PersistenceRecorder {
    private(set) var lastSaved: AppSettings?

    func record(_ settings: AppSettings) {
        lastSaved = settings
    }
}

private actor ControlledPersistenceRecorder {
    private var persisted: [AppSettings] = []
    private var saveCallCount = 0
    private var firstSaveReleaseContinuation: CheckedContinuation<Void, Never>?

    func persist(_ settings: AppSettings) async {
        saveCallCount += 1
        if saveCallCount == 1 {
            await withCheckedContinuation { continuation in
                firstSaveReleaseContinuation = continuation
            }
        }

        persisted.append(settings)
    }

    func waitForFirstSaveToStart() async {
        while saveCallCount == 0 {
            await Task.yield()
        }
    }

    func allowFirstSaveToFinish() {
        firstSaveReleaseContinuation?.resume()
        firstSaveReleaseContinuation = nil
    }

    func lastSaved() -> AppSettings? {
        persisted.last
    }

    func saveCount() -> Int {
        persisted.count
    }
}

private final class InMemorySettingsService: SettingsServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var value: AppSettings = AppSettings()

    func loadSettings() -> AppSettings {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func saveSettings(_ settings: AppSettings) throws {
        lock.lock()
        value = settings.validated()
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
