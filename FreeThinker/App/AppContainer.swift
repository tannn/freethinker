import AppKit
import Foundation

@MainActor
public final class AppContainer {
    public let appState: AppState
    public let aiService: any AIServiceProtocol
    public let textCaptureService: any TextCaptureServiceProtocol
    public let orchestrator: any ProvocationOrchestrating
    public let hotkeyService: any GlobalHotkeyServiceProtocol
    public let menuBarCoordinator: MenuBarCoordinator
    public let settingsService: any SettingsServiceProtocol
    public let diagnosticsLogger: any DiagnosticsLogging

    private let errorMapper: ErrorPresentationMapping
    private let launchAtLoginController: any LaunchAtLoginControlling
    private let modelAvailabilityProvider: any FoundationModelsAdapterProtocol

    private let settingsWindowController: SettingsWindowController
    private var onboardingWindowController: OnboardingWindowController?

    public init(
        appState: AppState,
        aiService: any AIServiceProtocol = DefaultAIService(),
        textCaptureService: any TextCaptureServiceProtocol = DefaultTextCaptureService(),
        notificationService: any UserNotificationServiceProtocol = LoggerUserNotificationService(),
        errorMapper: ErrorPresentationMapping = ErrorPresentationMapper(),
        hotkeyService: any GlobalHotkeyServiceProtocol,
        launchAtLoginController: any LaunchAtLoginControlling = LaunchAtLoginService(),
        settingsService: any SettingsServiceProtocol = DefaultSettingsService(),
        diagnosticsLogger: any DiagnosticsLogging = DiagnosticsLogger(),
        modelAvailabilityProvider: any FoundationModelsAdapterProtocol = FoundationModelsAdapter()
    ) {
        self.appState = appState
        self.aiService = aiService
        self.textCaptureService = textCaptureService
        self.errorMapper = errorMapper
        self.hotkeyService = hotkeyService
        self.launchAtLoginController = launchAtLoginController
        self.settingsService = settingsService
        self.diagnosticsLogger = diagnosticsLogger
        self.modelAvailabilityProvider = modelAvailabilityProvider

        let callbacks = AppContainer.makeCallbacks(
            appState: appState,
            notificationService: notificationService
        )

        let orchestrator = ProvocationOrchestrator(
            textCaptureService: textCaptureService,
            aiService: aiService,
            settingsProvider: {
                await MainActor.run { appState.settings }
            },
            errorMapper: errorMapper,
            callbacks: callbacks,
            diagnosticsLogger: diagnosticsLogger
        )
        self.orchestrator = orchestrator

        menuBarCoordinator = MenuBarCoordinator(
            appState: appState,
            orchestrator: orchestrator
        )

        settingsWindowController = SettingsWindowController(appState: appState)

        wireCallbacks()
    }

    public convenience init() {
        let settingsService = DefaultSettingsService()
        let loadedSettings = settingsService.loadSettings()
        let textCaptureService = DefaultTextCaptureService(
            fallbackCaptureEnabled: loadedSettings.fallbackCaptureEnabled
        )

        self.init(
            appState: AppState(settings: loadedSettings),
            aiService: DefaultAIService(),
            textCaptureService: textCaptureService,
            notificationService: LoggerUserNotificationService(),
            errorMapper: ErrorPresentationMapper(),
            hotkeyService: GlobalHotkeyService(),
            launchAtLoginController: LaunchAtLoginService(),
            settingsService: settingsService,
            diagnosticsLogger: DiagnosticsLogger(),
            modelAvailabilityProvider: FoundationModelsAdapter()
        )
    }

    public func start() {
        var settings = appState.settings

        if settings.hotkeyEnabled == false, settings.showMenuBarIcon == false {
            Logger.warning(
                "Recovered unreachable startup settings by re-enabling menu bar icon and opening Settings.",
                category: .settings
            )
            settings.showMenuBarIcon = true
            appState.updateSettings(settings)
            settings = appState.settings
            appState.openSettings(section: .general)
        }

        let launchAtLoginEnabled = launchAtLoginController.isEnabled()
        if settings.launchAtLogin != launchAtLoginEnabled {
            settings.launchAtLogin = launchAtLoginEnabled
            appState.updateSettings(settings)
            settings = appState.settings
        }

        hotkeyService.onTrigger = { [weak self] in
            guard let self else { return }
            Task {
                _ = await self.orchestrator.trigger(source: .hotkey, regenerateFromResponseID: nil)
            }
        }

        hotkeyService.onRegistrationError = { [weak self] error in
            guard let self else { return }
            self.presentHotkeyRegistrationError(error)
        }

        hotkeyService.refreshRegistration(using: settings)

        Task {
            await textCaptureService.setFallbackCaptureEnabled(settings.fallbackCaptureEnabled)
        }

        if settings.showMenuBarIcon {
            menuBarCoordinator.installStatusItemIfNeeded()
        } else {
            menuBarCoordinator.uninstallStatusItem()
        }

        diagnosticsLogger.setEnabled(settings.diagnosticsEnabled)
        diagnosticsLogger.record(
            stage: .appLifecycle,
            category: .info,
            message: "App container started",
            metadata: ["menu_bar_icon": "\(settings.showMenuBarIcon)"]
        )

        syncLaunchAtLoginFromSystem()
        refreshOnboardingReadiness()

        if appState.isOnboardingPresented {
            openOnboardingWindow()
        }
    }

    public func stop() {
        Task {
            await orchestrator.cancelCurrentGeneration(reason: .appWillTerminate)
        }
        hotkeyService.unregister()
        menuBarCoordinator.uninstallStatusItem()

        diagnosticsLogger.record(
            stage: .appLifecycle,
            category: .info,
            message: "App container stopping",
            metadata: [:]
        )
    }
}

private extension AppContainer {
    func wireCallbacks() {
        appState.onRegenerateRequested = { [weak self] responseID in
            guard let self else { return }
            _ = await self.orchestrator.trigger(source: .regenerate, regenerateFromResponseID: responseID)
        }

        appState.onCloseRequested = { [weak self] in
            guard let self else { return }
            Task {
                await self.orchestrator.cancelCurrentGeneration(reason: .userClosedPanel)
            }
        }

        appState.onSettingsUpdated = { [weak self] settings in
            guard let self else { return }
            self.hotkeyService.refreshRegistration(using: settings)
            self.diagnosticsLogger.setEnabled(settings.diagnosticsEnabled)
            Task {
                await self.textCaptureService.setFallbackCaptureEnabled(settings.fallbackCaptureEnabled)
            }

            if settings.showMenuBarIcon {
                self.menuBarCoordinator.installStatusItemIfNeeded()
            } else {
                self.menuBarCoordinator.uninstallStatusItem()
            }

            self.diagnosticsLogger.record(
                stage: .settings,
                category: .info,
                message: "Settings updated",
                metadata: [
                    "diagnostics_enabled": "\(settings.diagnosticsEnabled)",
                    "launch_at_login": "\(settings.launchAtLogin)"
                ]
            )
        }

        appState.onSettingsPersistRequested = { [weak self] settings in
            guard let self else { return }
            do {
                try self.settingsService.saveSettings(settings)
            } catch {
                Logger.warning("Settings persistence failed error=\(error.localizedDescription)", category: .settings)
                throw error
            }
        }

        appState.onOnboardingPresentationChanged = { [weak self] isPresented in
            guard let self else { return }
            if isPresented {
                self.refreshOnboardingReadiness()
                self.openOnboardingWindow()
            } else {
                self.onboardingWindowController?.hide()
            }
        }

        appState.onLaunchAtLoginChangeRequested = { [weak self] isEnabled in
            guard let self else { return }
            try self.launchAtLoginController.setEnabled(isEnabled)
        }

        appState.onOpenSettingsRequested = { [weak self] section in
            self?.settingsWindowController.show(section: section)
        }

        appState.onExportDiagnosticsRequested = { [weak self] in
            self?.exportDiagnosticsLog() ?? "Export unavailable"
        }

        menuBarCoordinator.onOpenSettings = { [weak self] in
            self?.appState.openSettings(section: .general)
        }

        menuBarCoordinator.onOpenOnboardingGuide = { [weak self] in
            self?.appState.presentOnboarding()
        }

        menuBarCoordinator.onCheckForUpdates = { [weak self] in
            self?.checkForUpdates()
        }

        settingsWindowController.onCheckForUpdates = { [weak self] in
            self?.menuBarCoordinator.onCheckForUpdates?()
        }
    }

    func presentHotkeyRegistrationError(_ error: GlobalHotkeyServiceError) {
        ensureReachableAfterHotkeyFailure()

        let presentation = errorMapper.map(error: error.mappedFreeThinkerError, source: .hotkey)
        appState.presentErrorPresentation(presentation)
    }

    func ensureReachableAfterHotkeyFailure() {
        guard appState.settings.showMenuBarIcon == false else {
            return
        }

        Logger.warning(
            "Hotkey failed while menu bar icon hidden; re-enabling status item for recovery.",
            category: .hotkey
        )

        var settings = appState.settings
        settings.showMenuBarIcon = true
        appState.updateSettings(settings)
        appState.openSettings(section: .general)
    }

    func syncLaunchAtLoginFromSystem() {
        let actualState = launchAtLoginController.isEnabled()
        guard actualState != appState.settings.launchAtLogin else {
            return
        }

        var settings = appState.settings
        settings.launchAtLogin = actualState
        appState.updateSettings(settings)
    }

    func setLaunchAtLogin(_ targetState: Bool) {
        do {
            try launchAtLoginController.setEnabled(targetState)

            var settings = appState.settings
            settings.launchAtLogin = targetState
            appState.updateSettings(settings)
        } catch {
            Logger.warning("Launch at login update failed error=\(error.localizedDescription)", category: .settings)
            appState.presentErrorMessage("Could not update launch at login. Verify app permissions and retry.")
        }
    }

    func openOnboardingWindow() {
        if onboardingWindowController == nil {
            onboardingWindowController = OnboardingWindowController(
                appState: appState,
                openAccessibilitySettings: { [weak self] in
                    self?.openAccessibilitySettings()
                },
                openModelSettings: { [weak self] in
                    self?.openModelSupportSettings()
                },
                refreshReadiness: { [weak self] in
                    self?.refreshOnboardingReadiness()
                }
            )
        }

        onboardingWindowController?.show()
    }

    func refreshOnboardingReadiness() {
        Task {
            let permission = await textCaptureService.preflightPermission()
            let modelAvailability = modelAvailabilityProvider.availability()

            await MainActor.run {
                appState.updateOnboardingSystemReadiness(
                    accessibilityGranted: permission == .granted,
                    modelAvailability: modelAvailability
                )
            }
        }
    }

    func openAccessibilitySettings() {
        openSystemSettings(
            primaryURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            fallbackURL: "x-apple.systempreferences:com.apple.SystemSettings"
        )
    }

    func openModelSupportSettings() {
        openSystemSettings(
            primaryURL: "x-apple.systempreferences:com.apple.preference.siri",
            fallbackURL: "x-apple.systempreferences:com.apple.SystemSettings"
        )
    }

    func openSystemSettings(primaryURL: String, fallbackURL: String) {
        if
            let primary = URL(string: primaryURL),
            NSWorkspace.shared.open(primary)
        {
            return
        }

        if let fallback = URL(string: fallbackURL) {
            _ = NSWorkspace.shared.open(fallback)
        }
    }

    func exportDiagnosticsLog() -> String {
        guard !diagnosticsLogger.recentEvents().isEmpty else {
            return "No diagnostics captured yet"
        }

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "freethinker-diagnostics.json"
        savePanel.title = "Export Diagnostics"
        savePanel.message = "Select where to save diagnostics JSON"

        guard savePanel.runModal() == .OK, let url = savePanel.url else {
            return "Export cancelled"
        }

        do {
            try diagnosticsLogger.exportEvents(to: url)
            diagnosticsLogger.record(
                stage: .export,
                category: .info,
                message: "Diagnostics exported",
                metadata: ["destination": url.lastPathComponent]
            )
            return "Exported to \(url.lastPathComponent)"
        } catch {
            Logger.warning("Diagnostics export failed error=\(error.localizedDescription)", category: .diagnostics)
            return "Export failed: \(error.localizedDescription)"
        }
    }

    func checkForUpdates() {
        if let releaseURL = ProcessInfo.processInfo.environment["FREETHINKER_RELEASE_URL"],
           let url = URL(string: releaseURL)
        {
            _ = NSWorkspace.shared.open(url)
            return
        }

        appState.presentErrorMessage("Updates are delivered via direct download in this build. Set FREETHINKER_RELEASE_URL for quick access.")
    }

    static func makeCallbacks(
        appState: AppState,
        notificationService: any UserNotificationServiceProtocol
    ) -> ProvocationOrchestratorCallbacks {
        ProvocationOrchestratorCallbacks(
            setGenerating: { isGenerating in
                await MainActor.run {
                    appState.setGenerating(isGenerating)
                }
            },
            presentLoading: { selectedText in
                await MainActor.run {
                    appState.presentLoading(selectedText: selectedText)
                }
            },
            presentResponse: { response in
                await MainActor.run {
                    appState.present(response: response)
                }
            },
            presentError: { presentation in
                await MainActor.run {
                    appState.presentErrorPresentation(presentation)
                }
            },
            isPanelVisible: {
                await MainActor.run {
                    appState.isPanelVisible
                }
            },
            notifyBackgroundMessage: { message in
                await notificationService.post(message: message)
            }
        )
    }
}
