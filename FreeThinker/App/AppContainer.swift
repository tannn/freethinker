import AppKit
import Foundation
import KeyboardShortcuts

/// The composition root for the FreeThinker app.
///
/// `AppContainer` creates and wires all core services, coordinates lifecycle events,
/// and provides the single point of truth for dependency injection. It is `@MainActor`-isolated
/// because it directly owns and manipulates `AppState`.
///
/// Typical usage:
/// ```swift
/// let container = AppContainer()
/// container.start()
/// // … app runs …
/// container.stop()
/// ```
@MainActor
public final class AppContainer {
    /// The shared observable app state consumed by SwiftUI views.
    public let appState: AppState
    /// The AI service that performs on-device text generation.
    public let aiService: any AIServiceProtocol
    /// The service responsible for capturing selected text from the active app.
    public let textCaptureService: any TextCaptureServiceProtocol
    /// The orchestrator that coordinates the end-to-end generation pipeline.
    public let orchestrator: any ProvocationOrchestrating
    /// Manages the menu bar status item and its menu.
    public let menuBarCoordinator: MenuBarCoordinator
    /// Persists and loads ``AppSettings`` to and from disk.
    public let settingsService: any SettingsServiceProtocol
    /// Records diagnostic events for troubleshooting.
    public let diagnosticsLogger: any DiagnosticsLogging

    private let errorMapper: ErrorPresentationMapping
    private let launchAtLoginController: any LaunchAtLoginControlling
    private let modelAvailabilityProvider: any FoundationModelsAdapterProtocol

    private let settingsWindowController: SettingsWindowController
    private let floatingPanelController: FloatingPanelController
    private var onboardingWindowController: OnboardingWindowController?

    /// Creates an `AppContainer` with explicit dependencies, suitable for testing.
    ///
    /// - Parameters:
    ///   - appState: The shared observable state object.
    ///   - aiService: Service performing AI generation.
    ///   - textCaptureService: Service capturing the user's selected text.
    ///   - notificationService: Service posting background user notifications.
    ///   - errorMapper: Maps ``FreeThinkerError`` values to ``ErrorPresentation`` instances.
    ///   - launchAtLoginController: Manages the Launch at Login system setting.
    ///   - settingsService: Reads and writes ``AppSettings`` to disk.
    ///   - diagnosticsLogger: Records diagnostic events.
    ///   - modelAvailabilityProvider: Probes whether the on-device AI model is available.
    public init(
        appState: AppState,
        aiService: any AIServiceProtocol = DefaultAIService(),
        textCaptureService: any TextCaptureServiceProtocol = DefaultTextCaptureService(),
        notificationService: any UserNotificationServiceProtocol = LoggerUserNotificationService(),
        errorMapper: ErrorPresentationMapping = ErrorPresentationMapper(),
        launchAtLoginController: any LaunchAtLoginControlling = LaunchAtLoginService(),
        settingsService: any SettingsServiceProtocol = DefaultSettingsService(),
        diagnosticsLogger: any DiagnosticsLogging = DiagnosticsLogger(),
        modelAvailabilityProvider: any FoundationModelsAdapterProtocol = FoundationModelsAdapter()
    ) {
        self.appState = appState
        self.aiService = aiService
        self.textCaptureService = textCaptureService
        self.errorMapper = errorMapper
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
        floatingPanelController = FloatingPanelController(viewModel: appState.panelViewModel)
        appState.attachPanelController(floatingPanelController)

        wireCallbacks()
    }

    /// Creates an `AppContainer` with all production dependencies.
    ///
    /// Loads persisted settings via `DefaultSettingsService` before constructing the state.
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
            launchAtLoginController: LaunchAtLoginService(),
            settingsService: settingsService,
            diagnosticsLogger: DiagnosticsLogger(),
            modelAvailabilityProvider: FoundationModelsAdapter()
        )
    }

    /// Starts the container and all managed services.
    ///
    /// - Recovers unreachable startup settings (hotkey and menu bar both disabled).
    /// - Syncs the Launch at Login setting from the system.
    /// - Registers the global hotkey.
    /// - Installs or removes the menu bar status item based on settings.
    /// - Refreshes onboarding readiness.
    /// - Presents the onboarding window if not previously completed.
    ///
    /// Must be called once after the app delegate's `applicationDidFinishLaunching`.
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

        HotkeyCoordinator.shared.onTrigger = { [weak self] in
            guard let self else { return }
            Task {
                _ = await self.orchestrator.trigger(source: .hotkey, regenerateFromResponseID: nil)
            }
        }

        HotkeyCoordinator.shared.refresh(using: settings)

        // Hotkey registration callbacks may mutate reachability settings.
        settings = appState.settings

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

    /// Gracefully shuts down the container.
    ///
    /// Cancels any in-flight generation, cleans up the floating panel, stops the global
    /// hotkey listener, and removes the menu bar status item. Call from
    /// `applicationWillTerminate`.
    public func stop() {
        Task {
            await orchestrator.cancelCurrentGeneration(reason: .appWillTerminate)
        }
        floatingPanelController.cleanup()
        HotkeyCoordinator.shared.stopListening()
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
            HotkeyCoordinator.shared.refresh(using: settings)
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

        appState.onHotkeyValidationRequested = { proposedShortcut, effectiveShortcut in
            return HotkeyValidationResult.valid(
                proposedShortcut: proposedShortcut,
                effectiveShortcut: proposedShortcut
            )
        }

        appState.onHotkeyApplyRequested = { _ in
            return
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
