import Foundation

enum SettingsServiceError: Error, LocalizedError, Equatable, Sendable {
    case encodeFailed(details: String)
    case decodeFailed(details: String)
    case persistenceFailed(details: String)
    case migrationFailed(details: String)

    var errorDescription: String? {
        switch self {
        case let .encodeFailed(details):
            return "Unable to encode settings: \(details)"
        case let .decodeFailed(details):
            return "Unable to decode settings: \(details)"
        case let .persistenceFailed(details):
            return "Unable to persist settings: \(details)"
        case let .migrationFailed(details):
            return "Unable to migrate settings: \(details)"
        }
    }
}

/// Contract for settings persistence backed by local storage.
/// Thread safety: implementers must provide atomic read/write semantics.
protocol SettingsService: Sendable {
    func load() async -> Result<AppSettings, SettingsServiceError>
    func save(_ settings: AppSettings) async -> Result<Void, SettingsServiceError>
    func resetToDefaults(preservingLaunchAtLogin: Bool) async -> Result<AppSettings, SettingsServiceError>
}

extension SettingsService {
    func resetToDefaults() async -> Result<AppSettings, SettingsServiceError> {
        await resetToDefaults(preservingLaunchAtLogin: true)
    }
}
