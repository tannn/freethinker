import Foundation

actor DefaultSettingsService: SettingsService {
    enum StorageKeys {
        static let appSettingsPayload = "freethinker.app.settings.payload"
        static let schemaVersion = "freethinker.app.settings.schemaVersion"
    }

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() async -> Result<AppSettings, SettingsServiceError> {
        do {
            let loadedSettings = try loadCurrentSettings()
            return .success(loadedSettings)
        } catch let error as SettingsServiceError {
            return .failure(error)
        } catch {
            return .failure(.persistenceFailed(details: error.localizedDescription))
        }
    }

    func save(_ settings: AppSettings) async -> Result<Void, SettingsServiceError> {
        do {
            try persist(settings.normalizedForPersistence())
            return .success(())
        } catch let error as SettingsServiceError {
            return .failure(error)
        } catch {
            return .failure(.persistenceFailed(details: error.localizedDescription))
        }
    }

    func resetToDefaults(preservingLaunchAtLogin: Bool) async -> Result<AppSettings, SettingsServiceError> {
        do {
            let currentSettings = try loadCurrentSettings()
            var defaults = AppSettings.defaultValue

            if preservingLaunchAtLogin {
                defaults.launchAtLogin = currentSettings.launchAtLogin
            }

            try persist(defaults.normalizedForPersistence())
            AppLog.settings.notice("Settings reset to defaults (preserving launch at login: \(preservingLaunchAtLogin)).")
            return .success(defaults)
        } catch let error as SettingsServiceError {
            return .failure(error)
        } catch {
            return .failure(.persistenceFailed(details: error.localizedDescription))
        }
    }

    private func loadCurrentSettings() throws -> AppSettings {
        guard let rawData = userDefaults.data(forKey: StorageKeys.appSettingsPayload) else {
            let defaultSettings = AppSettings.defaultValue.normalizedForPersistence()
            try persist(defaultSettings)
            AppLog.settings.info("No saved settings found; using defaults.")
            return defaultSettings
        }

        let decodedSettings: AppSettings

        do {
            decodedSettings = try decoder.decode(AppSettings.self, from: rawData)
        } catch {
            throw SettingsServiceError.decodeFailed(details: error.localizedDescription)
        }

        let persistedSchemaVersion = userDefaults.object(forKey: StorageKeys.schemaVersion) as? Int
        let sourceVersion = max(
            max(1, persistedSchemaVersion ?? 0),
            decodedSettings.schemaVersion
        )

        let migratedSettings = try migrateIfNeeded(
            decodedSettings.normalized(),
            fromVersion: sourceVersion
        )

        if migratedSettings != decodedSettings || sourceVersion != AppSettings.currentSchemaVersion {
            try persist(migratedSettings)
            AppLog.settings.notice("Applied settings migration to schema \(AppSettings.currentSchemaVersion).")
        }

        return migratedSettings
    }

    private func persist(_ settings: AppSettings) throws {
        do {
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: StorageKeys.appSettingsPayload)
            userDefaults.set(settings.schemaVersion, forKey: StorageKeys.schemaVersion)
        } catch {
            throw SettingsServiceError.encodeFailed(details: error.localizedDescription)
        }
    }

    private func migrateIfNeeded(_ settings: AppSettings, fromVersion: Int) throws -> AppSettings {
        guard fromVersion <= AppSettings.currentSchemaVersion else {
            // Forward compatibility: preserve unknown future schema values in payload.
            return settings.normalized()
        }

        var migrated = settings
        var version = fromVersion

        while version < AppSettings.currentSchemaVersion {
            switch version {
            case 1:
                AppLog.settings.notice("Migrating settings schema from 1 to 2.")
                migrated = migrateV1ToV2(migrated)
                version = 2
            default:
                throw SettingsServiceError.migrationFailed(details: "Unsupported migration path from version \(version).")
            }
        }

        migrated.schemaVersion = AppSettings.currentSchemaVersion
        return migrated.normalized()
    }

    private func migrateV1ToV2(_ settings: AppSettings) -> AppSettings {
        var migrated = settings

        if let autoDismissSeconds = migrated.autoDismissSeconds,
           autoDismissSeconds <= 0 {
            migrated.autoDismissSeconds = nil
            AppLog.settings.info("Cleared invalid auto-dismiss value while migrating settings.")
        }

        return migrated
    }
}
