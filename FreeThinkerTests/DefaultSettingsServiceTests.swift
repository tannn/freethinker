import AppKit
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
        settings.hotkeyModifiers = 1_048_576
        settings.hotkeyKeyCode = 11
        settings.diagnosticsEnabled = true
        settings.hasSeenOnboarding = true
        settings.onboardingCompleted = true
        settings.hotkeyAwarenessConfirmed = true
        settings.launchAtLogin = true
        settings.autoDismissSeconds = 10
        settings.fallbackCaptureEnabled = false
        settings.provocationStylePreset = .systemsThinking
        settings.customStyleInstructions = "Challenge second-order effects."
        settings.appUpdateChannel = .beta
        settings.hotkeyModifiers = Int(NSEvent.ModifierFlags.command.union(.option).rawValue)
        settings.hotkeyKeyCode = 46

        try service.saveSettings(settings)
        let loaded = service.loadSettings()

        XCTAssertEqual(loaded.hotkeyModifiers, 1_048_576)
        XCTAssertEqual(loaded.hotkeyKeyCode, 11)
        XCTAssertEqual(loaded.diagnosticsEnabled, true)
        XCTAssertEqual(loaded.hasSeenOnboarding, true)
        XCTAssertEqual(loaded.onboardingCompleted, true)
        XCTAssertEqual(loaded.hotkeyAwarenessConfirmed, true)
        XCTAssertEqual(loaded.launchAtLogin, true)
        XCTAssertEqual(loaded.autoDismissSeconds, 10)
        XCTAssertEqual(loaded.fallbackCaptureEnabled, false)
        XCTAssertEqual(loaded.provocationStylePreset, .systemsThinking)
        XCTAssertEqual(loaded.customStyleInstructions, "Challenge second-order effects.")
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

    func testFR010_RejectedHotkeyKeyCodeFallsBackToDefaultAcrossLoad_SC03() throws {
        let defaults = makeDefaults()
        let service = DefaultSettingsService(userDefaults: defaults)

        let invalid = AppSettings(hotkeyKeyCode: 999)
        try service.saveSettings(invalid)

        let loaded = service.loadSettings()
        XCTAssertEqual(loaded.hotkeyKeyCode, 35)
    }

    func testFR011_ResetStyleCustomizationPersistsDefaultState_SC02() throws {
        let defaults = makeDefaults()
        let service = DefaultSettingsService(userDefaults: defaults)

        let customized = AppSettings(
            provocationStylePreset: .contrarian,
            customStyleInstructions: "Interrogate incentive asymmetry."
        )
        try service.saveSettings(customized)

        try service.saveSettings(
            AppSettings(
                provocationStylePreset: .socratic,
                customStyleInstructions: ""
            )
        )

        let loaded = service.loadSettings()
        XCTAssertEqual(loaded.provocationStylePreset, .socratic)
        XCTAssertTrue(loaded.customStyleInstructions.isEmpty)
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
