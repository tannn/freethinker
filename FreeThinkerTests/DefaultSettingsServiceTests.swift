import Foundation
import XCTest
@testable import FreeThinker

final class DefaultSettingsServiceTests: XCTestCase {
    func testLoadReturnsDefaultsWhenNoPersistedValue() {
        let service = DefaultSettingsService(userDefaults: makeDefaults())
        let loaded = service.loadSettings()
        XCTAssertEqual(loaded, AppSettings().validated())
    }

    func testSaveAndLoadRoundTrip() throws {
        let defaults = makeDefaults()
        let service = DefaultSettingsService(userDefaults: defaults)

        var settings = AppSettings()
        settings.diagnosticsEnabled = true
        settings.hasSeenOnboarding = true
        settings.onboardingCompleted = true
        settings.hotkeyAwarenessConfirmed = true
        settings.launchAtLogin = true
        settings.autoDismissSeconds = 10
        settings.fallbackCaptureEnabled = false
        settings.appUpdateChannel = .beta

        try service.saveSettings(settings)
        let loaded = service.loadSettings()

        XCTAssertEqual(loaded.diagnosticsEnabled, true)
        XCTAssertEqual(loaded.hasSeenOnboarding, true)
        XCTAssertEqual(loaded.onboardingCompleted, true)
        XCTAssertEqual(loaded.hotkeyAwarenessConfirmed, true)
        XCTAssertEqual(loaded.launchAtLogin, true)
        XCTAssertEqual(loaded.autoDismissSeconds, 10)
        XCTAssertEqual(loaded.fallbackCaptureEnabled, false)
        XCTAssertEqual(loaded.appUpdateChannel, .beta)
    }

    func testLoadSupportsLegacyPayloadWithoutNewFields() throws {
        let defaults = makeDefaults()

        let legacyPayload = """
        {
          "schemaVersion": 1,
          "hotkeyEnabled": true,
          "hotkeyModifiers": 1179648,
          "hotkeyKeyCode": 35,
          "prompt1": "p1",
          "prompt2": "p2",
          "launchAtLogin": false,
          "selectedModel": "default",
          "showMenuBarIcon": true,
          "dismissOnCopy": true,
          "provocationStylePreset": "socratic",
          "customStyleInstructions": "",
          "aiTimeoutSeconds": 5
        }
        """
        defaults.set(legacyPayload.data(using: .utf8), forKey: "app.settings.v2")

        let service = DefaultSettingsService(userDefaults: defaults)
        let loaded = service.loadSettings()

        XCTAssertEqual(loaded.schemaVersion, AppSettings.currentSchemaVersion)
        XCTAssertEqual(loaded.diagnosticsEnabled, false)
        XCTAssertEqual(loaded.hasSeenOnboarding, false)
        XCTAssertEqual(loaded.onboardingCompleted, false)
        XCTAssertEqual(loaded.hotkeyAwarenessConfirmed, false)
        XCTAssertEqual(loaded.autoDismissSeconds, 6)
        XCTAssertEqual(loaded.fallbackCaptureEnabled, true)
        XCTAssertEqual(loaded.automaticallyCheckForUpdates, true)
        XCTAssertEqual(loaded.appUpdateChannel, .stable)
    }

    func testLoadMigratesFromLegacyStorageKey() throws {
        let defaults = makeDefaults()
        let service = DefaultSettingsService(userDefaults: defaults)

        var legacySettings = AppSettings(schemaVersion: 1)
        legacySettings.prompt1 = "legacy prompt"
        let encodedLegacy = try JSONEncoder().encode(legacySettings)
        defaults.set(encodedLegacy, forKey: "app.settings.v1")

        let loaded = service.loadSettings()

        XCTAssertEqual(loaded.prompt1, "legacy prompt")
        XCTAssertNotNil(defaults.data(forKey: "app.settings.v2"))
        XCTAssertNil(defaults.data(forKey: "app.settings.v1"))
    }
}

private extension DefaultSettingsServiceTests {
    func makeDefaults() -> UserDefaults {
        let suite = "settings-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
