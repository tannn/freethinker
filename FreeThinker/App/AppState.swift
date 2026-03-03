import AppKit
import Combine
import Foundation

/// Protocol for persisting and loading the floating panel's pinned state.
public protocol PanelPinningStore {
    /// Loads the previously saved pinned state.
    ///
    /// - Returns: `true` if the panel was pinned when last saved; `false` otherwise.
    func loadPinnedState() -> Bool

    /// Persists the current pinned state.
    ///
    /// - Parameter isPinned: The pinned state to save.
    func savePinnedState(_ isPinned: Bool)
}

/// `UserDefaults`-backed implementation of ``PanelPinningStore``.
public struct UserDefaultsPanelPinningStore: PanelPinningStore {
    private let userDefaults: UserDefaults
    private let key: String

    /// Creates a store backed by the given `UserDefaults` instance.
    ///
    /// - Parameters:
    ///   - userDefaults: The `UserDefaults` to read from and write to. Defaults to `.standard`.
    ///   - key: The key used to store the pinned state. Defaults to `"floating_panel.is_pinned"`.
    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "floating_panel.is_pinned"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    /// Loads the pinned state from `UserDefaults`, returning `false` if no value has been saved.
    public func loadPinnedState() -> Bool {
        userDefaults.object(forKey: key) as? Bool ?? false
    }

    /// Saves the pinned state to `UserDefaults`.
    ///
    /// - Parameter isPinned: The value to persist.
    public func savePinnedState(_ isPinned: Bool) {
        userDefaults.set(isPinned, forKey: key)
    }
}

/// Tracks whether the user has completed each item on the onboarding checklist.
public struct OnboardingReadiness: Equatable, Sendable {
    /// Whether Accessibility permission has been granted.
    public var accessibilityGranted: Bool
    /// Whether the user has acknowledged the global hotkey.
    public var hotkeyAwarenessConfirmed: Bool
    /// The current availability of the on-device AI model.
    public var modelAvailability: FoundationModelAvailability

    /// Creates a readiness snapshot with all items defaulting to incomplete.
    ///
    /// - Parameters:
    ///   - accessibilityGranted: Whether Accessibility permission is granted. Defaults to `false`.
    ///   - hotkeyAwarenessConfirmed: Whether the hotkey step is confirmed. Defaults to `false`.
    ///   - modelAvailability: Current model availability. Defaults to ``FoundationModelAvailability/modelUnavailable``.
    public init(
        accessibilityGranted: Bool = false,
        hotkeyAwarenessConfirmed: Bool = false,
        modelAvailability: FoundationModelAvailability = .modelUnavailable
    ) {
        self.accessibilityGranted = accessibilityGranted
        self.hotkeyAwarenessConfirmed = hotkeyAwarenessConfirmed
        self.modelAvailability = modelAvailability
    }

    /// `true` when the model reports ``FoundationModelAvailability/available``.
    public var isModelReady: Bool {
        modelAvailability == .available
    }

    /// `true` when all three checklist items are complete.
    public var isChecklistComplete: Bool {
        accessibilityGranted && hotkeyAwarenessConfirmed && isModelReady
    }
}

/// The central observable state object for the FreeThinker app.
///
/// `AppState` is confined to the `@MainActor` and drives SwiftUI views via `@Published` properties.
/// It delegates side-effects (generation, settings persistence, hotkey management) to callback
/// closures wired by ``AppContainer`` at startup.
@MainActor
public final class AppState: ObservableObject {
    /// The validated app settings currently in effect.
    @Published public private(set) var settings: AppSettings
    /// `true` while the AI generation pipeline is running.
    @Published public private(set) var isGenerating: Bool = false
    /// A localised error message shown when settings cannot be persisted, or `nil` when clear.
    @Published public private(set) var settingsSaveErrorMessage: String?
    /// A validation message shown when proposed settings are invalid, or `nil` when valid.
    @Published public private(set) var settingsValidationMessage: String?
    /// `true` while a settings save operation is in progress.
    @Published public private(set) var isPersistingSettings: Bool = false
    /// The result of the most recent hotkey validation or apply attempt, or `nil` if none.
    @Published public private(set) var hotkeyCustomizationResult: HotkeyValidationResult?

    /// Whether the onboarding flow is currently presented.
    @Published public private(set) var isOnboardingPresented: Bool
    /// The current state of each onboarding prerequisite.
    @Published public private(set) var onboardingReadiness: OnboardingReadiness

    /// The view model driving the floating panel UI.
    public let panelViewModel: FloatingPanelViewModel

    /// Called when the user requests regeneration from within the panel.
    ///
    /// - Parameter regenerateFromResponseID: The ID of the response whose original text should be reused, or `nil`.
    public var onRegenerateRequested: ((_ regenerateFromResponseID: UUID?) async -> Void)?

    /// Called when the user dismisses the floating panel.
    public var onCloseRequested: (() -> Void)?

    /// Called synchronously after settings are validated and applied in-memory.
    ///
    /// - Parameter settings: The newly active ``AppSettings`` value.
    public var onSettingsUpdated: ((AppSettings) -> Void)?

    /// Called asynchronously to persist settings to disk.
    ///
    /// - Parameter settings: The settings to persist.
    /// - Throws: ``SettingsServiceError`` or other errors if persistence fails.
    public var onSettingsPersistRequested: ((AppSettings) async throws -> Void)?

    /// Called to validate a proposed hotkey shortcut before applying it.
    ///
    /// - Parameters:
    ///   - proposedShortcut: The shortcut the user wants to use.
    ///   - effectiveShortcut: The shortcut currently registered.
    /// - Returns: A ``HotkeyValidationResult`` indicating whether the shortcut is acceptable.
    public var onHotkeyValidationRequested: ((HotkeyShortcut, HotkeyShortcut) -> HotkeyValidationResult)?

    /// Called to apply a validated hotkey shortcut by registering it with the system.
    ///
    /// - Parameter settings: The settings containing the new shortcut.
    /// - Throws: An error if the shortcut cannot be registered.
    public var onHotkeyApplyRequested: ((AppSettings) throws -> Void)?

    /// Called when the user toggles Launch at Login.
    ///
    /// - Parameter isEnabled: The desired launch-at-login state.
    /// - Throws: ``LaunchAtLoginError`` if the system cannot honour the request.
    public var onLaunchAtLoginChangeRequested: ((Bool) async throws -> Void)?

    /// Called when the app should open a specific settings section.
    ///
    /// - Parameter section: The section to navigate to.
    public var onOpenSettingsRequested: ((SettingsSection) -> Void)?

    /// Called whenever the onboarding presentation state changes.
    ///
    /// - Parameter isPresented: `true` if onboarding is now visible.
    public var onOnboardingPresentationChanged: ((Bool) -> Void)?

    /// Called when the user requests a diagnostics export; returns a summary string.
    public var onExportDiagnosticsRequested: (() -> String)?

    private let pinningStore: any PanelPinningStore
    private var panelController: FloatingPanelController?
    private var pendingSettingsSave: AppSettings?
    private var settingsSaveTask: Task<Void, Never>?

    /// Creates an `AppState` with the given settings and dependencies.
    ///
    /// Settings are validated before use. The onboarding flag is derived from
    /// `settings.hasSeenOnboarding`.
    ///
    /// - Parameters:
    ///   - settings: Initial app settings. Defaults to `AppSettings()`.
    ///   - pinningStore: Store used to persist the panel's pinned state.
    ///   - timing: Timing provider for the panel view model's auto-dismiss and feedback timers.
    ///   - pasteboardWriter: Closure that writes text to the pasteboard. Defaults to `NSPasteboard.general`.
    public init(
        settings: AppSettings = AppSettings(),
        pinningStore: any PanelPinningStore = UserDefaultsPanelPinningStore(),
        timing: any FloatingPanelTiming = SystemFloatingPanelTiming(),
        pasteboardWriter: ((String) -> Void)? = nil
    ) {
        let validatedSettings = settings.validated()

        let resolvedPasteboardWriter: (String) -> Void = pasteboardWriter ?? { text in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }

        self.settings = validatedSettings
        self.pinningStore = pinningStore
        self.isOnboardingPresented = !validatedSettings.hasSeenOnboarding
        self.onboardingReadiness = OnboardingReadiness(
            hotkeyAwarenessConfirmed: validatedSettings.hotkeyAwarenessConfirmed
        )

        panelViewModel = FloatingPanelViewModel(
            isPinned: pinningStore.loadPinnedState(),
            dismissOnCopy: validatedSettings.dismissOnCopy,
            autoDismissSeconds: validatedSettings.autoDismissSeconds,
            timing: timing,
            pasteboardWriter: resolvedPasteboardWriter,
            styleDisplayName: validatedSettings.provocationStylePreset.displayName
        )

        panelViewModel.onPinStateChanged = { [weak self] isPinned in
            self?.pinningStore.savePinnedState(isPinned)
        }

        panelViewModel.onRegenerateRequested = { [weak self] responseID in
            await self?.onRegenerateRequested?(responseID)
        }

        panelViewModel.onCloseRequested = { [weak self] in
            self?.onCloseRequested?()
            self?.panelController?.hide()
        }
        panelViewModel.styleDisplayName = validatedSettings.provocationStylePreset.displayName
    }

    /// Attaches a floating panel controller so AppState can show and hide the panel.
    ///
    /// Call this once after the controller is created, before any generation is triggered.
    ///
    /// - Parameter controller: The ``FloatingPanelController`` to use.
    public func attachPanelController(_ controller: FloatingPanelController) {
        panelController = controller
    }

    /// Shows the floating panel in a loading state and sets `isGenerating` to `true`.
    ///
    /// - Parameter selectedText: An optional preview of the selected text to display while loading.
    public func presentLoading(selectedText: String? = nil) {
        isGenerating = true
        panelViewModel.setLoading(selectedTextPreview: selectedText)
        panelController?.show()
    }

    /// Presents a completed provocation response in the floating panel.
    ///
    /// Sets `isGenerating` to `false`. On success, the panel shows the content;
    /// on failure, it shows an error derived from `response.error`.
    ///
    /// - Parameter response: The ``ProvocationResponse`` to display.
    public func present(response: ProvocationResponse) {
        isGenerating = false
        panelController?.show()

        if case .success = response.outcome {
            panelViewModel.setSuccess(response)
            return
        }

        panelViewModel.setError(response.error ?? .generationFailed)
    }

    /// Presents a ``FreeThinkerError`` in the floating panel and clears `isGenerating`.
    ///
    /// - Parameter error: The error to display.
    public func presentError(_ error: FreeThinkerError) {
        isGenerating = false
        panelController?.show()
        panelViewModel.setError(error)
    }

    /// Presents a mapped ``ErrorPresentation`` (with suggested action) in the floating panel.
    ///
    /// - Parameter presentation: The presentation value produced by ``ErrorPresentationMapping``.
    public func presentErrorPresentation(_ presentation: ErrorPresentation) {
        isGenerating = false
        panelController?.show()
        panelViewModel.setErrorPresentation(presentation)
    }

    /// Presents a plain error message string in the floating panel.
    ///
    /// - Parameter message: The localised error message to show.
    public func presentErrorMessage(_ message: String) {
        isGenerating = false
        panelController?.show()
        panelViewModel.setErrorMessage(message)
    }

    /// Hides the floating panel and resets the panel view model to idle.
    public func dismissPanel() {
        isGenerating = false
        panelViewModel.setIdle()
        panelController?.hide()
    }

    /// Validates and applies new settings, persisting them if a persist handler is configured.
    ///
    /// If validation fails, `settingsValidationMessage` is set and no changes are applied.
    /// If the settings are unchanged, only `onboardingReadiness.hotkeyAwarenessConfirmed`
    /// is refreshed. Calls ``onSettingsUpdated`` synchronously after applying.
    ///
    /// - Parameter settings: The new settings to validate and apply.
    public func updateSettings(_ settings: AppSettings) {
        let candidate = settings.validated()
        guard let validationIssue = validateSettings(candidate) else {
            settingsValidationMessage = nil
            if onSettingsPersistRequested == nil {
                settingsSaveErrorMessage = nil
            }

            guard candidate != self.settings else {
                onboardingReadiness.hotkeyAwarenessConfirmed = candidate.hotkeyAwarenessConfirmed
                return
            }

            self.settings = candidate
            panelViewModel.dismissOnCopy = self.settings.dismissOnCopy
            panelViewModel.autoDismissSeconds = self.settings.autoDismissSeconds
            panelViewModel.styleDisplayName = self.settings.provocationStylePreset.displayName
            onboardingReadiness.hotkeyAwarenessConfirmed = self.settings.hotkeyAwarenessConfirmed
            onSettingsUpdated?(self.settings)
            persistSettingsIfNeeded(self.settings)
            return
        }

        settingsValidationMessage = validationIssue
    }

    /// Sets the `isGenerating` flag directly.
    ///
    /// Primarily called by the orchestrator via its callback closure.
    ///
    /// - Parameter isGenerating: The new generating state.
    public func setGenerating(_ isGenerating: Bool) {
        self.isGenerating = isGenerating
    }

    /// Shows the onboarding flow and notifies the presentation change callback.
    public func presentOnboarding() {
        isOnboardingPresented = true
        notifyOnboardingVisibilityChanged()
    }

    /// Dismisses the onboarding flow.
    ///
    /// - Parameter markSeen: When `true` (the default), `settings.hasSeenOnboarding` is set
    ///   and changes are persisted so onboarding does not reappear at next launch.
    public func dismissOnboarding(markSeen: Bool = true) {
        if markSeen, !settings.hasSeenOnboarding {
            var updated = settings
            updated.hasSeenOnboarding = true
            self.settings = updated.validated()
            onSettingsUpdated?(self.settings)
            persistSettingsIfNeeded(self.settings)
        }

        isOnboardingPresented = false
        notifyOnboardingVisibilityChanged()
    }

    /// Marks onboarding as fully complete, persists settings, and dismisses the flow.
    public func completeOnboarding() {
        var updated = settings
        updated.hasSeenOnboarding = true
        updated.onboardingCompleted = true
        updated.hotkeyAwarenessConfirmed = onboardingReadiness.hotkeyAwarenessConfirmed
        self.settings = updated.validated()
        onSettingsUpdated?(self.settings)
        persistSettingsIfNeeded(self.settings)

        isOnboardingPresented = false
        notifyOnboardingVisibilityChanged()
    }

    /// Records that the user has acknowledged the global hotkey and persists the change.
    ///
    /// - Parameter isConfirmed: Whether the user has confirmed hotkey awareness.
    public func setHotkeyAwarenessConfirmed(_ isConfirmed: Bool) {
        onboardingReadiness.hotkeyAwarenessConfirmed = isConfirmed

        var updated = settings
        updated.hotkeyAwarenessConfirmed = isConfirmed
        self.settings = updated.validated()
        onSettingsUpdated?(self.settings)
        persistSettingsIfNeeded(self.settings)
    }

    /// Updates the system-level readiness items that cannot be self-reported by the user.
    ///
    /// Call this after probing Accessibility permission and model availability.
    ///
    /// - Parameters:
    ///   - accessibilityGranted: Whether AX permission is currently granted.
    ///   - modelAvailability: The current availability of the on-device AI model.
    public func updateOnboardingSystemReadiness(
        accessibilityGranted: Bool,
        modelAvailability: FoundationModelAvailability
    ) {
        onboardingReadiness.accessibilityGranted = accessibilityGranted
        onboardingReadiness.modelAvailability = modelAvailability
    }

    /// Whether the floating panel's window is currently visible on screen.
    public var isPanelVisible: Bool {
        panelController?.panel.isVisible ?? false
    }

    /// Applies a mutation closure to the current settings and calls ``updateSettings(_:)``.
    ///
    /// - Parameter mutation: A closure that modifies the settings in-place.
    public func mutateSettings(_ mutation: (inout AppSettings) -> Void) async {
        var next = settings
        mutation(&next)
        updateSettings(next)
    }

    public func setDismissOnCopy(_ isEnabled: Bool) async {
        await mutateSettings { $0.dismissOnCopy = isEnabled }
    }

    public func setAutoDismissSeconds(_ seconds: TimeInterval) async {
        await mutateSettings { $0.autoDismissSeconds = seconds }
    }

    public func setHotkeyEnabled(_ isEnabled: Bool) async {
        await mutateSettings { $0.hotkeyEnabled = isEnabled }
    }

    /// Validates a proposed hotkey shortcut without applying it.
    ///
    /// Returns `.valid` with the proposed shortcut if no validation handler is set.
    ///
    /// - Parameter shortcut: The shortcut to validate.
    /// - Returns: A ``HotkeyValidationResult`` describing whether the shortcut is acceptable.
    public func proposeHotkeyShortcut(_ shortcut: HotkeyShortcut) -> HotkeyValidationResult {
        let effectiveShortcut = settings.hotkeyShortcut
        guard let onHotkeyValidationRequested else {
            return .valid(
                proposedShortcut: shortcut,
                effectiveShortcut: shortcut
            )
        }

        return onHotkeyValidationRequested(shortcut, effectiveShortcut)
    }

    /// Validates and applies a hotkey shortcut, updating settings and the UI.
    ///
    /// If validation or system registration fails, the current shortcut is preserved and
    /// `hotkeyCustomizationResult` is set to the rejected result.
    ///
    /// - Parameter shortcut: The shortcut to apply.
    /// - Returns: A ``HotkeyValidationResult`` reflecting the outcome.
    @discardableResult
    public func applyHotkeyShortcut(_ shortcut: HotkeyShortcut) -> HotkeyValidationResult {
        let previousShortcut = settings.hotkeyShortcut
        let proposedResult = proposeHotkeyShortcut(shortcut)

        guard proposedResult.isAccepted else {
            settingsValidationMessage = proposedResult.message
            hotkeyCustomizationResult = proposedResult
            return proposedResult
        }

        var updated = settings
        updated.hotkeyShortcut = proposedResult.effectiveShortcut

        do {
            try onHotkeyApplyRequested?(updated)
        } catch {
            let rejected = HotkeyValidationResult.invalid(
                proposedShortcut: proposedResult.proposedShortcut,
                effectiveShortcut: previousShortcut,
                message: "This shortcut could not be applied. Try a different key combination."
            )
            settingsValidationMessage = rejected.message
            hotkeyCustomizationResult = rejected
            return rejected
        }

        updateSettings(updated)

        let message = previousShortcut == proposedResult.effectiveShortcut
            ? "Global hotkey unchanged."
            : "Global hotkey updated."
        let accepted = HotkeyValidationResult.valid(
            proposedShortcut: proposedResult.proposedShortcut,
            effectiveShortcut: proposedResult.effectiveShortcut,
            message: message
        )
        settingsValidationMessage = nil
        hotkeyCustomizationResult = accepted
        return accepted
    }

    /// Resets the global hotkey to the default shortcut (Cmd+Shift+P).
    ///
    /// - Returns: The validation result for the reset operation.
    @discardableResult
    public func resetHotkeyShortcutToDefault() -> HotkeyValidationResult {
        let result = applyHotkeyShortcut(.defaultShortcut)
        guard result.isAccepted else {
            return result
        }

        let resetResult = HotkeyValidationResult.valid(
            proposedShortcut: result.proposedShortcut,
            effectiveShortcut: result.effectiveShortcut,
            message: "Global hotkey reset to Cmd+Shift+P."
        )
        hotkeyCustomizationResult = resetResult
        return resetResult
    }

    public func setShowMenuBarIcon(_ isEnabled: Bool) async {
        await mutateSettings { $0.showMenuBarIcon = isEnabled }
    }

    public func setFallbackCaptureEnabled(_ isEnabled: Bool) async {
        await mutateSettings { $0.fallbackCaptureEnabled = isEnabled }
    }

    public func setPanelPinned(_ isPinned: Bool) async {
        guard panelViewModel.isPinned != isPinned else {
            return
        }
        panelViewModel.togglePin()
    }

    public func setAutomaticallyCheckForUpdates(_ isEnabled: Bool) async {
        await mutateSettings { $0.automaticallyCheckForUpdates = isEnabled }
    }

    public func setAppUpdateChannel(_ channel: AppUpdateChannel) async {
        await mutateSettings { $0.appUpdateChannel = channel }
    }

    public func setProvocationStylePreset(_ preset: ProvocationStylePreset) async {
        await mutateSettings { $0.provocationStylePreset = preset }
    }

    public func setCustomStyleInstructions(_ instructions: String) async {
        await mutateSettings { $0.customStyleInstructions = instructions }
    }

    public func resetProvocationStyleCustomization() async {
        await mutateSettings {
            $0.provocationStylePreset = .socratic
            $0.customStyleInstructions = ""
        }
    }

    /// Requests the system to enable or disable Launch at Login, then persists the change.
    ///
    /// On failure, `settingsSaveErrorMessage` is populated with a localised reason string.
    ///
    /// - Parameter isEnabled: The desired launch-at-login state.
    public func setLaunchAtLoginEnabled(_ isEnabled: Bool) async {
        settingsSaveErrorMessage = nil

        do {
            try await onLaunchAtLoginChangeRequested?(isEnabled)
        } catch {
            let reason = mapSettingsError(error)
            settingsSaveErrorMessage = "Could not update Launch at Login. \(reason)"
            return
        }

        await mutateSettings { $0.launchAtLogin = isEnabled }
    }

    /// Asks the host to open the settings window at the specified section.
    ///
    /// - Parameter section: The section to navigate to. Defaults to `.general`.
    public func openSettings(section: SettingsSection = .general) {
        onOpenSettingsRequested?(section)
    }

    /// Clears all transient settings feedback (errors, validation messages, hotkey results).
    public func clearSettingsFeedback() {
        settingsSaveErrorMessage = nil
        settingsValidationMessage = nil
        hotkeyCustomizationResult = nil
    }
}

private extension AppState {
    func validateSettings(_ settings: AppSettings) -> String? {
        if settings.hotkeyEnabled == false, settings.showMenuBarIcon == false {
            return "Keep either Global Hotkey or Menu Bar Icon enabled so FreeThinker stays reachable."
        }

        return nil
    }

    func persistSettingsIfNeeded(_ settings: AppSettings) {
        guard onSettingsPersistRequested != nil else {
            return
        }

        pendingSettingsSave = settings
        isPersistingSettings = true

        guard settingsSaveTask == nil else {
            return
        }

        settingsSaveTask = Task { [weak self] in
            await self?.drainPendingSettingsSaves()
        }
    }

    func drainPendingSettingsSaves() async {
        defer {
            settingsSaveTask = nil
            isPersistingSettings = false
        }

        while let settingsToPersist = pendingSettingsSave {
            pendingSettingsSave = nil
            guard let onSettingsPersistRequested else {
                continue
            }

            do {
                try await onSettingsPersistRequested(settingsToPersist)
                settingsSaveErrorMessage = nil
            } catch {
                settingsSaveErrorMessage = "Could not save settings. \(mapSettingsError(error))"
            }
        }
    }

    func mapSettingsError(_ error: Error) -> String {
        if let launchError = error as? LaunchAtLoginError {
            switch launchError {
            case .unsupported:
                return "Launch at Login is not supported on this macOS configuration."
            case .failed(let message):
                return message
            }
        }

        if let settingsError = error as? SettingsServiceError {
            switch settingsError {
            case .encodingFailed:
                return "Your changes are active now but may not persist after relaunch."
            }
        }

        return error.localizedDescription
    }

    func notifyOnboardingVisibilityChanged() {
        onOnboardingPresentationChanged?(isOnboardingPresented)
    }
}

