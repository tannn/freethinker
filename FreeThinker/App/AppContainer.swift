import Foundation
import ServiceManagement

@MainActor
final class AppContainer {
    let settingsService: any SettingsService
    lazy var aiService: any AIService = DeferredAIService()
    lazy var textCaptureService: any TextCaptureService = DeferredTextCaptureService()

    init() {
        settingsService = UserDefaultsSettingsService()
    }

    func setLaunchAtLogin(_ enabled: Bool) async -> Result<Void, SettingsServiceError> {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try await SMAppService.mainApp.unregister()
            }
            return .success(())
        } catch {
            AppLog.settings.error("Unable to update launch-at-login state: \(error.localizedDescription)")
            return .failure(.persistenceFailed(details: error.localizedDescription))
        }
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

private actor UserDefaultsSettingsService: SettingsService {
    private enum StorageKeys {
        static let appSettings = "freethinker.app.settings"
    }

    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load() async -> Result<AppSettings, SettingsServiceError> {
        guard let data = userDefaults.data(forKey: StorageKeys.appSettings) else {
            return .success(.defaultValue)
        }

        do {
            let settings = try decoder.decode(AppSettings.self, from: data)
            return .success(settings)
        } catch {
            return .failure(.decodeFailed(details: error.localizedDescription))
        }
    }

    func save(_ settings: AppSettings) async -> Result<Void, SettingsServiceError> {
        do {
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: StorageKeys.appSettings)
            return .success(())
        } catch {
            return .failure(.encodeFailed(details: error.localizedDescription))
        }
    }
}
