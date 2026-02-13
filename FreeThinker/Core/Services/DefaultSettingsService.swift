import Foundation

public protocol SettingsServiceProtocol: Sendable {
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings) throws
}

public enum SettingsServiceError: Error, Equatable, Sendable {
    case encodingFailed
}

public final class DefaultSettingsService: SettingsServiceProtocol, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let storageKey: String
    private let lock = NSLock()

    public init(
        userDefaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        storageKey: String = "freethinker.app_settings"
    ) {
        self.userDefaults = userDefaults
        self.encoder = encoder
        self.decoder = decoder
        self.storageKey = storageKey
    }

    public func loadSettings() -> AppSettings {
        lock.lock()
        defer { lock.unlock() }

        guard let data = userDefaults.data(forKey: storageKey) else {
            return AppSettings()
        }

        do {
            return try decoder.decode(AppSettings.self, from: data).validated()
        } catch {
            Logger.warning(
                "Settings decode failed; falling back to defaults error=\(error.localizedDescription)",
                category: .settings
            )
            return AppSettings()
        }
    }

    public func saveSettings(_ settings: AppSettings) throws {
        lock.lock()
        defer { lock.unlock() }

        do {
            let data = try encoder.encode(settings.validated())
            userDefaults.set(data, forKey: storageKey)
        } catch {
            throw SettingsServiceError.encodingFailed
        }
    }
}
