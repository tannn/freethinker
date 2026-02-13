import Foundation

@MainActor
public final class AppContainer {
    public let appState: AppState
    public let aiService: any AIServiceProtocol
    public let textCaptureService: any TextCaptureServiceProtocol
    public let orchestrator: any ProvocationOrchestrating
    public let hotkeyService: any GlobalHotkeyServiceProtocol
    public let menuBarCoordinator: MenuBarCoordinator
    public let settingsWindowController: SettingsWindowController

    private let errorMapper: ErrorPresentationMapping
    private let settingsService: any SettingsServiceProtocol
    private let launchAtLoginController: any LaunchAtLoginControlling

    public init(
        appState: AppState,
        aiService: any AIServiceProtocol = DefaultAIService(),
        textCaptureService: any TextCaptureServiceProtocol = DefaultTextCaptureService(),
        notificationService: any UserNotificationServiceProtocol = LoggerUserNotificationService(),
        errorMapper: ErrorPresentationMapping = ErrorPresentationMapper(),
        hotkeyService: any GlobalHotkeyServiceProtocol,
        launchAtLoginController: any LaunchAtLoginControlling = LaunchAtLoginService(),
        settingsService: any SettingsServiceProtocol = DefaultSettingsService()
    ) {
        self.appState = appState
        self.aiService = aiService
        self.textCaptureService = textCaptureService
        self.errorMapper = errorMapper
        self.hotkeyService = hotkeyService
        self.launchAtLoginController = launchAtLoginController
        self.settingsService = settingsService

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
            callbacks: callbacks
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

        self.init(
            appState: AppState(settings: loadedSettings),
            aiService: DefaultAIService(),
            textCaptureService: DefaultTextCaptureService(),
            notificationService: LoggerUserNotificationService(),
            errorMapper: ErrorPresentationMapper(),
            hotkeyService: GlobalHotkeyService(),
            launchAtLoginController: LaunchAtLoginService(),
            settingsService: settingsService
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

        if settings.showMenuBarIcon {
            menuBarCoordinator.installStatusItemIfNeeded()
        } else {
            menuBarCoordinator.uninstallStatusItem()
        }
    }

    public func stop() {
        Task {
            await orchestrator.cancelCurrentGeneration(reason: .appWillTerminate)
        }
        hotkeyService.unregister()
        menuBarCoordinator.uninstallStatusItem()
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

            if settings.showMenuBarIcon {
                self.menuBarCoordinator.installStatusItemIfNeeded()
            } else {
                self.menuBarCoordinator.uninstallStatusItem()
            }
        }

        appState.onSettingsPersistRequested = { [weak self] settings in
            guard let self else { return }
            try self.settingsService.saveSettings(settings)
        }

        appState.onLaunchAtLoginChangeRequested = { [weak self] isEnabled in
            guard let self else { return }
            try self.launchAtLoginController.setEnabled(isEnabled)
        }

        appState.onOpenSettingsRequested = { [weak self] section in
            self?.settingsWindowController.show(section: section)
        }

        menuBarCoordinator.onOpenSettings = { [weak self] in
            self?.appState.openSettings(section: .general)
        }

        menuBarCoordinator.onCheckForUpdates = { [weak self] in
            self?.appState.presentErrorMessage("Updater integration ships in WP08. Select channel in Settings now.")
        }

        settingsWindowController.onCheckForUpdates = { [weak self] in
            self?.menuBarCoordinator.onCheckForUpdates?()
        }
    }

    func presentHotkeyRegistrationError(_ error: GlobalHotkeyServiceError) {
        let presentation = errorMapper.map(error: error.mappedFreeThinkerError, source: .hotkey)
        appState.presentErrorPresentation(presentation)
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
