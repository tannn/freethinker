import XCTest
@testable import FreeThinker

final class SettingsServiceTests: XCTestCase {
    func testLoadReturnsDefaultSettingsWhenNoDataExists() async {
        let userDefaults = makeIsolatedUserDefaults()
        let service = DefaultSettingsService(userDefaults: userDefaults)

        let result = await service.load()
        let loadedSettings = unwrap(result)

        XCTAssertEqual(loadedSettings, AppSettings.defaultValue)
        XCTAssertEqual(loadedSettings.schemaVersion, AppSettings.currentSchemaVersion)
    }

    func testSavePersistsAndCanReloadValues() async {
        let userDefaults = makeIsolatedUserDefaults()
        let service = DefaultSettingsService(userDefaults: userDefaults)

        var updatedSettings = AppSettings.defaultValue
        updatedSettings.hotkeyEnabled = false
        updatedSettings.panelBehavior = .pinned
        updatedSettings.provocationStyle = .provocative
        updatedSettings.launchAtLogin = true
        updatedSettings.autoDismissSeconds = 25

        let saveResult = await service.save(updatedSettings)
        XCTAssertTrue(saveResult.isSuccess)

        let reloadedSettings = unwrap(await service.load())
        XCTAssertEqual(reloadedSettings.hotkeyEnabled, false)
        XCTAssertEqual(reloadedSettings.panelBehavior, .pinned)
        XCTAssertEqual(reloadedSettings.provocationStyle, .provocative)
        XCTAssertEqual(reloadedSettings.launchAtLogin, true)
        XCTAssertEqual(reloadedSettings.autoDismissSeconds, 25)
    }

    func testLoadMigratesLegacySettingsAndWritesCurrentSchema() async throws {
        let userDefaults = makeIsolatedUserDefaults()

        let legacySettings = AppSettings(
            schemaVersion: 1,
            hotkeyEnabled: true,
            hotkeyShortcut: .init(key: "x", modifiers: []),
            panelBehavior: .centered,
            provocationStyle: .analytical,
            launchAtLogin: true,
            autoDismissSeconds: 0
        )

        let data = try JSONEncoder().encode(legacySettings)
        userDefaults.set(data, forKey: DefaultSettingsService.StorageKeys.appSettingsPayload)
        userDefaults.set(1, forKey: DefaultSettingsService.StorageKeys.schemaVersion)

        let service = DefaultSettingsService(userDefaults: userDefaults)
        let migratedSettings = unwrap(await service.load())

        XCTAssertEqual(migratedSettings.schemaVersion, AppSettings.currentSchemaVersion)
        XCTAssertEqual(migratedSettings.hotkeyShortcut.key, "X")
        XCTAssertEqual(migratedSettings.hotkeyShortcut.modifiers, AppSettings.HotkeyShortcut.default.modifiers)
        XCTAssertNil(migratedSettings.autoDismissSeconds)
        XCTAssertEqual(
            userDefaults.integer(forKey: DefaultSettingsService.StorageKeys.schemaVersion),
            AppSettings.currentSchemaVersion
        )
    }

    func testMigrationIsIdempotentAcrossRepeatedLoads() async throws {
        let userDefaults = makeIsolatedUserDefaults()

        let legacySettings = AppSettings(schemaVersion: 1, autoDismissSeconds: -3)
        userDefaults.set(
            try JSONEncoder().encode(legacySettings),
            forKey: DefaultSettingsService.StorageKeys.appSettingsPayload
        )
        userDefaults.set(1, forKey: DefaultSettingsService.StorageKeys.schemaVersion)

        let service = DefaultSettingsService(userDefaults: userDefaults)
        let firstLoad = unwrap(await service.load())
        let firstData = userDefaults.data(forKey: DefaultSettingsService.StorageKeys.appSettingsPayload)
        let secondLoad = unwrap(await service.load())
        let secondData = userDefaults.data(forKey: DefaultSettingsService.StorageKeys.appSettingsPayload)

        XCTAssertEqual(firstLoad, secondLoad)
        XCTAssertEqual(firstData, secondData)
    }

    func testResetToDefaultsPreservesLaunchAtLoginByDefault() async {
        let userDefaults = makeIsolatedUserDefaults()
        let service = DefaultSettingsService(userDefaults: userDefaults)

        var customSettings = AppSettings.defaultValue
        customSettings.launchAtLogin = true
        customSettings.panelBehavior = .pinned
        customSettings.provocationStyle = .provocative
        customSettings.hotkeyEnabled = false

        _ = await service.save(customSettings)

        let resetSettings = unwrap(await service.resetToDefaults())

        XCTAssertEqual(resetSettings.launchAtLogin, true)
        XCTAssertEqual(resetSettings.panelBehavior, AppSettings.defaultValue.panelBehavior)
        XCTAssertEqual(resetSettings.provocationStyle, AppSettings.defaultValue.provocationStyle)
        XCTAssertEqual(resetSettings.hotkeyEnabled, AppSettings.defaultValue.hotkeyEnabled)
    }

    func testResetToDefaultsCanDisableLaunchAtLoginPreservation() async {
        let userDefaults = makeIsolatedUserDefaults()
        let service = DefaultSettingsService(userDefaults: userDefaults)

        var customSettings = AppSettings.defaultValue
        customSettings.launchAtLogin = true
        _ = await service.save(customSettings)

        let resetSettings = unwrap(await service.resetToDefaults(preservingLaunchAtLogin: false))

        XCTAssertEqual(resetSettings.launchAtLogin, AppSettings.defaultValue.launchAtLogin)
    }

    private func makeIsolatedUserDefaults() -> UserDefaults {
        let suiteName = "FreeThinkerTests.SettingsServiceTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }

    private func unwrap<T>(_ result: Result<T, SettingsServiceError>, file: StaticString = #filePath, line: UInt = #line) -> T {
        switch result {
        case let .success(value):
            return value
        case let .failure(error):
            XCTFail("Expected success but got error: \(error)", file: file, line: line)
            fatalError("Unreachable")
        }
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}
