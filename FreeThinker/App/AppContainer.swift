import Foundation

@MainActor
final class AppContainer {
    let settingsService: any SettingsService
    let launchAtLoginService: any LaunchAtLoginService
    let appState: AppState

    let aiService: any AIService
    let textCaptureService: any TextCaptureService

    init(
        settingsService: (any SettingsService)? = nil,
        launchAtLoginService: (any LaunchAtLoginService)? = nil,
        aiService: (any AIService)? = nil,
        textCaptureService: (any TextCaptureService)? = nil
    ) {
        let resolvedSettingsService = settingsService ?? DefaultSettingsService()
        let resolvedLaunchAtLoginService = launchAtLoginService ?? DefaultLaunchAtLoginService()

        self.settingsService = resolvedSettingsService
        self.launchAtLoginService = resolvedLaunchAtLoginService
        self.aiService = aiService ?? DeferredAIService()
        self.textCaptureService = textCaptureService ?? DeferredTextCaptureService()
        appState = AppState(
            settingsService: resolvedSettingsService,
            launchAtLoginService: resolvedLaunchAtLoginService
        )
    }
}

private actor DeferredAIService: AIService {
    func generateProvocation(for request: ProvocationRequest) async -> Result<ProvocationResponse, AIServiceError> {
        .failure(.notReady(message: "AI pipeline is not implemented yet."))
    }
}

private actor DeferredTextCaptureService: TextCaptureService {
    func captureSelectedText() async -> Result<CapturedText, TextCaptureError> {
        .failure(.unavailable(reason: "Text capture integration is not implemented yet."))
    }
}
