import AppKit
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
        await Task.yield()

        XCTAssertFalse(appState.settings.dismissOnCopy)
        XCTAssertEqual(appState.settings.autoDismissSeconds, 9)
        XCTAssertFalse(appState.settings.fallbackCaptureEnabled)

        let persisted = await recorder.lastSaved
        XCTAssertEqual(persisted?.dismissOnCopy, false)
        XCTAssertEqual(persisted?.autoDismissSeconds, 9)
        XCTAssertEqual(persisted?.fallbackCaptureEnabled, false)
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

    func testFR010_SettingsPersistAcrossRelaunchSimulation_SC01() async throws {
        let storage = InMemorySettingsService()

        let firstLaunch = makeAppState(settings: storage.loadSettings())
        firstLaunch.onSettingsPersistRequested = { settings in
            try storage.saveSettings(settings)
        }

        await firstLaunch.mutateSettings {
            $0.hotkeyModifiers = 1_048_576
            $0.hotkeyKeyCode = 11
        }
        await firstLaunch.setProvocationStylePreset(.systemsThinking)
        await firstLaunch.setCustomStyleInstructions("Challenge hidden second-order effects.")
        await Task.yield()

        let secondLaunch = makeAppState(settings: storage.loadSettings())
        XCTAssertEqual(secondLaunch.settings.hotkeyModifiers, 1_048_576)
        XCTAssertEqual(secondLaunch.settings.hotkeyKeyCode, 11)
        XCTAssertEqual(secondLaunch.settings.provocationStylePreset, .systemsThinking)
        XCTAssertEqual(secondLaunch.settings.customStyleInstructions, "Challenge hidden second-order effects.")
    }

    func testFR010_RejectedHotkeyProposalFallsBackAndDoesNotPersist_SC02() async throws {
        let storage = InMemorySettingsService()

        let firstLaunch = makeAppState(settings: storage.loadSettings())
        firstLaunch.onSettingsPersistRequested = { settings in
            try storage.saveSettings(settings)
        }

        await firstLaunch.mutateSettings {
            $0.hotkeyKeyCode = 999
        }
        await Task.yield()

        XCTAssertEqual(firstLaunch.settings.hotkeyKeyCode, 35)

        let secondLaunch = makeAppState(settings: storage.loadSettings())
        XCTAssertEqual(secondLaunch.settings.hotkeyKeyCode, 35)
    }

    func testFR011_ResetStyleCustomizationPersistsDefaultValues_SC01() async throws {
        let storage = InMemorySettingsService()

        let firstLaunch = makeAppState(settings: storage.loadSettings())
        firstLaunch.onSettingsPersistRequested = { settings in
            try storage.saveSettings(settings)
        }

        await firstLaunch.setProvocationStylePreset(.contrarian)
        await firstLaunch.setCustomStyleInstructions("Aggressively challenge unstated incentives.")
        await firstLaunch.resetProvocationStyleCustomization()
        await Task.yield()

        XCTAssertEqual(firstLaunch.settings.provocationStylePreset, .socratic)
        XCTAssertTrue(firstLaunch.settings.customStyleInstructions.isEmpty)

        let secondLaunch = makeAppState(settings: storage.loadSettings())
        XCTAssertEqual(secondLaunch.settings.provocationStylePreset, .socratic)
        XCTAssertTrue(secondLaunch.settings.customStyleInstructions.isEmpty)
    }

    func testMenuDrivenStylePresetSelectionUpdatesAndPersistsSettings() async throws {
        let recorder = PersistenceRecorder()
        let appState = makeAppState()
        appState.onSettingsPersistRequested = { settings in
            await recorder.record(settings)
        }

        let coordinator = MenuBarCoordinator(
            appState: appState,
            orchestrator: NoOpProvocationOrchestratorForSettingsUITests()
        )

        coordinator.perform(.selectStylePreset(.systemsThinking))
        try await waitUntil("systems thinking style set") {
            appState.settings.provocationStylePreset == .systemsThinking
        }
        try await waitUntil("systems thinking style persisted") {
            await recorder.lastSaved?.provocationStylePreset == .systemsThinking
        }

        coordinator.perform(.selectStylePreset(.contrarian))
        try await waitUntil("contrarian style set") {
            appState.settings.provocationStylePreset == .contrarian
        }
        try await waitUntil("contrarian style persisted") {
            await recorder.lastSaved?.provocationStylePreset == .contrarian
        }
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

    func testApplyHotkeyShortcutValidProposalPersistsShortcut() async {
        let recorder = CountingPersistenceRecorder()
        let appState = makeAppState()
        appState.onHotkeyValidationRequested = { proposed, _ in
            .valid(proposedShortcut: proposed, effectiveShortcut: proposed)
        }
        appState.onSettingsPersistRequested = { settings in
            await recorder.record(settings)
        }

        let proposed = HotkeyShortcut(
            modifiers: AppSettings.defaultHotkeyModifiers,
            keyCode: 40 // K
        )
        let result = appState.applyHotkeyShortcut(proposed)
        await Task.yield()

        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(appState.settings.hotkeyShortcut, proposed)
        let persisted = await recorder.lastSaved()
        XCTAssertEqual(persisted?.hotkeyShortcut, proposed)
    }

    func testRejectedHotkeyProposalsPreserveExistingShortcutAndDoNotPersist() async {
        let prior = AppSettings().hotkeyShortcut
        let proposed = HotkeyShortcut(modifiers: AppSettings.defaultHotkeyModifiers, keyCode: 40)
        let statuses: [HotkeyValidationStatus] = [.invalid, .reserved, .conflict]

        for status in statuses {
            let recorder = CountingPersistenceRecorder()
            let appState = makeAppState()
            appState.onSettingsPersistRequested = { settings in
                await recorder.record(settings)
            }
            appState.onHotkeyValidationRequested = { proposedShortcut, effectiveShortcut in
                HotkeyValidationResult(
                    status: status,
                    message: "\(status.rawValue) test failure",
                    proposedShortcut: proposedShortcut,
                    effectiveShortcut: effectiveShortcut
                )
            }

            let result = appState.applyHotkeyShortcut(proposed)
            await Task.yield()
            let saveCount = await recorder.saveCount()

            XCTAssertEqual(result.status, status)
            XCTAssertEqual(appState.settings.hotkeyShortcut, prior)
            XCTAssertEqual(saveCount, 0)
            XCTAssertEqual(appState.settingsValidationMessage, "\(status.rawValue) test failure")
        }
    }

    func testHotkeyApplyFailureSkipsPersistenceEvenAfterAcceptedValidation() async {
        let recorder = CountingPersistenceRecorder()
        let appState = makeAppState()
        appState.onHotkeyValidationRequested = { proposed, _ in
            .valid(proposedShortcut: proposed, effectiveShortcut: proposed)
        }
        appState.onHotkeyApplyRequested = { _ in
            throw GlobalHotkeyServiceError.conflict
        }
        appState.onSettingsPersistRequested = { settings in
            await recorder.record(settings)
        }

        let proposed = HotkeyShortcut(
            modifiers: AppSettings.defaultHotkeyModifiers,
            keyCode: 40
        )
        let result = appState.applyHotkeyShortcut(proposed)
        await Task.yield()

        XCTAssertEqual(result.status, .conflict)
        XCTAssertEqual(appState.settings.hotkeyShortcut, .defaultShortcut)
        let saveCount = await recorder.saveCount()
        XCTAssertEqual(saveCount, 0)
    }

    func testResetHotkeyShortcutToDefault() async {
        let recorder = CountingPersistenceRecorder()
        let customSettings = AppSettings(
            hotkeyModifiers: Int(NSEvent.ModifierFlags.command.rawValue),
            hotkeyKeyCode: 40
        )
        let appState = makeAppState(settings: customSettings)
        appState.onHotkeyValidationRequested = { proposed, _ in
            .valid(proposedShortcut: proposed, effectiveShortcut: proposed)
        }
        appState.onSettingsPersistRequested = { settings in
            await recorder.record(settings)
        }

        let result = appState.resetHotkeyShortcutToDefault()
        await Task.yield()

        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(appState.settings.hotkeyShortcut, .defaultShortcut)
        let persisted = await recorder.lastSaved()
        XCTAssertEqual(persisted?.hotkeyShortcut, .defaultShortcut)
        XCTAssertEqual(result.message, "Global hotkey reset to Cmd+Shift+P.")
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

    func testFR008_MenuStyleQuickSwitchCommandsSynchronizeWithSettings_SC01() async throws {
        let appState = makeAppState()
        let coordinator = MenuBarCoordinator(
            appState: appState,
            orchestrator: MockProvocationOrchestrator()
        )

        XCTAssertEqual(appState.settings.provocationStylePreset, .socratic)
        XCTAssertStyleSelection(
            in: coordinator.currentMenuDescriptors(),
            expectedCommand: .selectStylePreset(.socratic)
        )

        coordinator.perform(.selectStylePreset(.systemsThinking))
        await Task.yield()

        XCTAssertEqual(appState.settings.provocationStylePreset, .systemsThinking)
        XCTAssertStyleSelection(
            in: coordinator.currentMenuDescriptors(),
            expectedCommand: .selectStylePreset(.systemsThinking)
        )
    }

    func testFR007_RemovedUpdatesControlsStayHiddenInSettingsAndMenu_SC02() {
        XCTAssertEqual(
            SettingsSection.allCases,
            [.general, .provocation, .accessibilityHelp]
        )

        let appState = makeAppState()
        let coordinator = MenuBarCoordinator(
            appState: appState,
            orchestrator: MockProvocationOrchestrator()
        )
        XCTAssertFalse(
            coordinator.currentMenuDescriptors().contains { descriptor in
                descriptor.title == "Check for Updates"
            }
        )
    }

    func testSettingsAccessibilityIdentifiersRemainStable() {
        XCTAssertEqual(SettingsAccessibility.Identifier.root, "settings.root")
        XCTAssertEqual(SettingsAccessibility.Identifier.sectionGeneral, "settings.section.general")
        XCTAssertEqual(SettingsAccessibility.Identifier.sectionProvocation, "settings.section.provocation")
        XCTAssertEqual(SettingsAccessibility.Identifier.generalHotkeyEditor, "settings.general.hotkey_editor")
        XCTAssertEqual(SettingsAccessibility.Identifier.generalHotkeyResetButton, "settings.general.hotkey_reset")
        XCTAssertEqual(SettingsAccessibility.Identifier.generalHotkeyFeedback, "settings.general.hotkey_feedback")
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

    func XCTAssertStyleSelection(
        in descriptors: [MenuBarMenuItemDescriptor],
        expectedCommand: MenuBarCommand,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let styleDescriptors = descriptors.filter { descriptor in
            guard let command = descriptor.command else { return false }
            switch command {
            case .selectStylePreset:
                return true
            default:
                return false
            }
        }

        XCTAssertEqual(styleDescriptors.count, 3, file: file, line: line)

        for descriptor in styleDescriptors {
            guard let command = descriptor.command else {
                continue
            }
            XCTAssertEqual(descriptor.isOn, command == expectedCommand, file: file, line: line)
        }
    }
}

private actor PersistenceRecorder {
    private(set) var lastSaved: AppSettings?

    func record(_ settings: AppSettings) {
        lastSaved = settings
    }
}

private actor CountingPersistenceRecorder {
    private(set) var saved: [AppSettings] = []

    func record(_ settings: AppSettings) {
        saved.append(settings)
    }

    func saveCount() -> Int {
        saved.count
    }

    func lastSaved() -> AppSettings? {
        saved.last
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

private actor MockProvocationOrchestrator: ProvocationOrchestrating {
    func trigger(
        source: ProvocationTriggerSource,
        regenerateFromResponseID: UUID?
    ) async -> ProvocationTriggerDecision {
        .started
    }

    func cancelCurrentGeneration(reason: ProvocationCancellationReason) async {}

    func currentMetrics() -> ProvocationOrchestratorMetrics {
        ProvocationOrchestratorMetrics()
    }
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

private actor NoOpProvocationOrchestratorForSettingsUITests: ProvocationOrchestrating {
    func trigger(
        source: ProvocationTriggerSource,
        regenerateFromResponseID: UUID?
    ) async -> ProvocationTriggerDecision {
        .started
    }

    func cancelCurrentGeneration(reason: ProvocationCancellationReason) async {}

    func currentMetrics() -> ProvocationOrchestratorMetrics {
        ProvocationOrchestratorMetrics()
    }
}

private func waitUntil(
    _ label: String,
    timeoutNanoseconds: UInt64 = 1_000_000_000,
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
