import AppKit
import Combine
import Foundation

public protocol PanelPinningStore: Sendable {
    func loadPinnedState() -> Bool
    func savePinnedState(_ isPinned: Bool)
}

public final class UserDefaultsPanelPinningStore: PanelPinningStore, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let key: String

    public init(
        userDefaults: UserDefaults = .standard,
        key: String = "floating_panel.is_pinned"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public func loadPinnedState() -> Bool {
        userDefaults.object(forKey: key) as? Bool ?? false
    }

    public func savePinnedState(_ isPinned: Bool) {
        userDefaults.set(isPinned, forKey: key)
    }
}

@MainActor
public final class AppState: ObservableObject {
    @Published public private(set) var settings: AppSettings
    @Published public private(set) var isGenerating: Bool = false
    @Published public private(set) var settingsSaveErrorMessage: String?
    @Published public private(set) var settingsValidationMessage: String?
    @Published public private(set) var isPersistingSettings: Bool = false

    public let panelViewModel: FloatingPanelViewModel

    public var onRegenerateRequested: ((_ regenerateFromResponseID: UUID?) async -> Void)?
    public var onCloseRequested: (() -> Void)?
    public var onSettingsUpdated: ((AppSettings) -> Void)?
    public var onSettingsPersistRequested: ((AppSettings) async throws -> Void)?
    public var onLaunchAtLoginChangeRequested: ((Bool) async throws -> Void)?
    public var onOpenSettingsRequested: ((SettingsSection) -> Void)?

    private let pinningStore: any PanelPinningStore
    private var panelController: FloatingPanelController?
    private var settingsSaveToken: UInt64 = 0

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

        panelViewModel = FloatingPanelViewModel(
            isPinned: pinningStore.loadPinnedState(),
            dismissOnCopy: validatedSettings.dismissOnCopy,
            autoDismissSeconds: validatedSettings.autoDismissSeconds,
            timing: timing,
            pasteboardWriter: resolvedPasteboardWriter
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
    }

    public func attachPanelController(_ controller: FloatingPanelController) {
        panelController = controller
    }

    public func presentLoading(selectedText: String? = nil) {
        isGenerating = true
        panelViewModel.setLoading(selectedTextPreview: selectedText)
        panelController?.show()
    }

    public func present(response: ProvocationResponse) {
        isGenerating = false
        panelController?.show()

        if case .success = response.outcome {
            panelViewModel.setSuccess(response)
            return
        }

        panelViewModel.setError(response.error ?? .generationFailed)
    }

    public func presentError(_ error: FreeThinkerError) {
        isGenerating = false
        panelController?.show()
        panelViewModel.setError(error)
    }

    public func presentErrorPresentation(_ presentation: ErrorPresentation) {
        isGenerating = false
        panelController?.show()
        panelViewModel.setErrorPresentation(presentation)
    }

    public func presentErrorMessage(_ message: String) {
        isGenerating = false
        panelController?.show()
        panelViewModel.setErrorMessage(message)
    }

    public func dismissPanel() {
        isGenerating = false
        panelViewModel.setIdle()
        panelController?.hide()
    }

    public func updateSettings(_ settings: AppSettings) {
        let candidate = settings.validated()
        guard let validationIssue = validateSettings(candidate) else {
            settingsValidationMessage = nil
            if onSettingsPersistRequested == nil {
                settingsSaveErrorMessage = nil
            }

            guard candidate != self.settings else {
                return
            }

            self.settings = candidate
            panelViewModel.dismissOnCopy = self.settings.dismissOnCopy
            panelViewModel.autoDismissSeconds = self.settings.autoDismissSeconds
            onSettingsUpdated?(self.settings)
            persistSettingsIfNeeded(self.settings)
            return
        }

        settingsValidationMessage = validationIssue
    }

    public func setGenerating(_ isGenerating: Bool) {
        self.isGenerating = isGenerating
    }

    public var isPanelVisible: Bool {
        panelController?.panel.isVisible ?? false
    }

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

    public func openSettings(section: SettingsSection = .general) {
        onOpenSettingsRequested?(section)
    }

    public func clearSettingsFeedback() {
        settingsSaveErrorMessage = nil
        settingsValidationMessage = nil
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
        guard let onSettingsPersistRequested else {
            return
        }

        settingsSaveToken += 1
        let saveToken = settingsSaveToken
        isPersistingSettings = true

        Task { [weak self] in
            guard let self else { return }

            do {
                try await onSettingsPersistRequested(settings)
                await MainActor.run {
                    guard saveToken == self.settingsSaveToken else { return }
                    self.settingsSaveErrorMessage = nil
                    self.isPersistingSettings = false
                }
            } catch {
                await MainActor.run {
                    guard saveToken == self.settingsSaveToken else { return }
                    self.settingsSaveErrorMessage = "Could not save settings. \(self.mapSettingsError(error))"
                    self.isPersistingSettings = false
                }
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
}
