import Foundation

@MainActor
public final class AppContainer {
    public let appState: AppState
    public let aiService: any AIServiceProtocol
    public let textCaptureService: any TextCaptureServiceProtocol
    public let orchestrator: any ProvocationOrchestrating
    public let hotkeyService: any GlobalHotkeyServiceProtocol
    public let menuBarCoordinator: MenuBarCoordinator

    private let errorMapper: ErrorPresentationMapping

    public init(
        appState: AppState,
        aiService: any AIServiceProtocol = DefaultAIService(),
        textCaptureService: any TextCaptureServiceProtocol = DefaultTextCaptureService(),
        notificationService: any UserNotificationServiceProtocol = LoggerUserNotificationService(),
        errorMapper: ErrorPresentationMapping = ErrorPresentationMapper(),
        hotkeyService: any GlobalHotkeyServiceProtocol,
        launchAtLoginController: any LaunchAtLoginControlling = LaunchAtLoginService()
    ) {
        self.appState = appState
        self.aiService = aiService
        self.textCaptureService = textCaptureService
        self.errorMapper = errorMapper
        self.hotkeyService = hotkeyService

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
            orchestrator: orchestrator,
            launchAtLoginController: launchAtLoginController
        )

        wireCallbacks()
    }

    public convenience init() {
        self.init(
            appState: AppState(),
            aiService: DefaultAIService(),
            textCaptureService: DefaultTextCaptureService(),
            notificationService: LoggerUserNotificationService(),
            errorMapper: ErrorPresentationMapper(),
            hotkeyService: GlobalHotkeyService(),
            launchAtLoginController: LaunchAtLoginService()
        )
    }

    public func start() {
        let settings = appState.settings

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

        menuBarCoordinator.onOpenSettings = { [weak self] in
            self?.appState.presentErrorMessage("Settings window is not wired yet in this package target.")
        }

        menuBarCoordinator.onCheckForUpdates = { [weak self] in
            self?.appState.presentErrorMessage("Update checks are not wired yet in this package target.")
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
