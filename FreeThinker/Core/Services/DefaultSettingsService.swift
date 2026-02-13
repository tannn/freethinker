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
    private let legacyStorageKeys: [String]

    private let lock = NSLock()

    public init(
        userDefaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        storageKey: String = "app.settings.v2",
        legacyStorageKeys: [String] = [
            "app.settings.v1",
            "freethinker.app_settings"
        ]
    ) {
        self.userDefaults = userDefaults
        self.encoder = encoder
        self.decoder = decoder
        self.storageKey = storageKey
        self.legacyStorageKeys = legacyStorageKeys
    }

    public func loadSettings() -> AppSettings {
        lock.lock()
        defer { lock.unlock() }

        if let current = loadFromKey(storageKey) {
            return current
        }

        for legacyKey in legacyStorageKeys {
            guard legacyKey != storageKey else { continue }
            guard let migrated = loadFromKey(legacyKey) else { continue }

            do {
                try persistLocked(migrated)
                userDefaults.removeObject(forKey: legacyKey)
                Logger.info("Migrated settings from key=\(legacyKey) to key=\(storageKey)", category: .settings)
            } catch {
                Logger.warning(
                    "Settings migration persistence failed key=\(legacyKey) error=\(error.localizedDescription)",
                    category: .settings
                )
            }

            return migrated
        }

        return AppSettings().validated()
    }

    public func saveSettings(_ settings: AppSettings) throws {
        lock.lock()
        defer { lock.unlock() }
        try persistLocked(settings)
    }
}

private extension DefaultSettingsService {
    func loadFromKey(_ key: String) -> AppSettings? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }

        do {
            return try decoder.decode(AppSettings.self, from: data).validated()
        } catch {
            Logger.warning(
                "Settings decode failed key=\(key) error=\(error.localizedDescription)",
                category: .settings
            )
            return nil
        }
    }

    func persistLocked(_ settings: AppSettings) throws {
        do {
            let data = try encoder.encode(settings.validated())
            userDefaults.set(data, forKey: storageKey)
        } catch {
            throw SettingsServiceError.encodingFailed
        }
    }
}
