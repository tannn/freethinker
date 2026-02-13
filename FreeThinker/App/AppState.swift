import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    enum SettingsLoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    private let settingsService: any SettingsService
    private let launchAtLoginService: any LaunchAtLoginService

    private(set) var settings: AppSettings = .defaultValue
    private(set) var settingsLoadState: SettingsLoadState = .idle
    private(set) var statusMessage = "Settings not loaded"
    private(set) var lastError: FreeThinkerError?

    var launchAtLoginEnabled: Bool {
        settings.launchAtLogin
    }

    var selectedStyle: AppSettings.ProvocationStyle {
        settings.provocationStyle
    }

    init(
        settingsService: any SettingsService,
        launchAtLoginService: any LaunchAtLoginService
    ) {
        self.settingsService = settingsService
        self.launchAtLoginService = launchAtLoginService
    }

    func loadIfNeeded() async {
        guard settingsLoadState == .idle else {
            return
        }

        await refreshSettings()
    }

    func refreshSettings() async {
        settingsLoadState = .loading

        switch await settingsService.load() {
        case let .success(loadedSettings):
            settings = loadedSettings
            settingsLoadState = .loaded
            statusMessage = "Settings loaded"
            lastError = nil

            await synchronizeLaunchAtLoginStateIfNeeded()
        case let .failure(error):
            settingsLoadState = .failed
            statusMessage = error.localizedDescription
            lastError = .settings(error)
        }
    }

    func setHotkeyEnabled(_ enabled: Bool) async {
        await updateSettings("Hotkey preference saved") { settings in
            settings.hotkeyEnabled = enabled
        }
    }

    func setPanelBehavior(_ behavior: AppSettings.PanelBehavior) async {
        await updateSettings("Panel behavior saved") { settings in
            settings.panelBehavior = behavior
        }
    }

    func setProvocationStyle(_ style: AppSettings.ProvocationStyle) async {
        await updateSettings("Provocation style saved") { settings in
            settings.provocationStyle = style
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) async {
        let existingSettings = settings

        switch await launchAtLoginService.setEnabled(enabled) {
        case .success:
            var updatedSettings = existingSettings
            updatedSettings.launchAtLogin = enabled
            let normalizedUpdatedSettings = updatedSettings.normalizedForPersistence()

            switch await settingsService.save(normalizedUpdatedSettings) {
            case .success:
                settings = normalizedUpdatedSettings
                statusMessage = "Launch-at-login preference saved"
                lastError = nil
            case let .failure(error):
                _ = await launchAtLoginService.setEnabled(existingSettings.launchAtLogin)
                statusMessage = error.localizedDescription
                lastError = .settings(error)
            }
        case let .failure(error):
            statusMessage = error.localizedDescription
            lastError = .launchAtLogin(error)
        }
    }

    func resetSettingsToDefaults() async {
        switch await settingsService.resetToDefaults() {
        case let .success(defaultSettings):
            settings = defaultSettings
            statusMessage = "Settings reset"
            lastError = nil

            _ = await launchAtLoginService.setEnabled(defaultSettings.launchAtLogin)
        case let .failure(error):
            statusMessage = error.localizedDescription
            lastError = .settings(error)
        }
    }

    private func updateSettings(
        _ successMessage: String,
        mutate: (inout AppSettings) -> Void
    ) async {
        var candidate = settings
        mutate(&candidate)
        let normalizedCandidate = candidate.normalizedForPersistence()

        switch await settingsService.save(normalizedCandidate) {
        case .success:
            settings = normalizedCandidate
            statusMessage = successMessage
            lastError = nil
        case let .failure(error):
            statusMessage = error.localizedDescription
            lastError = .settings(error)
        }
    }

    private func synchronizeLaunchAtLoginStateIfNeeded() async {
        switch await launchAtLoginService.status() {
        case let .success(status):
            let serviceEnabled = status == .enabled || status == .requiresApproval
            guard serviceEnabled != settings.launchAtLogin else {
                return
            }

            var synchronizedSettings = settings
            synchronizedSettings.launchAtLogin = serviceEnabled
            let normalizedSynchronizedSettings = synchronizedSettings.normalizedForPersistence()

            switch await settingsService.save(normalizedSynchronizedSettings) {
            case .success:
                settings = normalizedSynchronizedSettings
                statusMessage = "Settings synchronized with system launch state"
            case let .failure(error):
                statusMessage = error.localizedDescription
                lastError = .settings(error)
            }
        case let .failure(error):
            statusMessage = error.localizedDescription
            lastError = .launchAtLogin(error)
        }
    }
}
