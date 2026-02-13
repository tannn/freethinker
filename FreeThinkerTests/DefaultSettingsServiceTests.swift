import XCTest
@testable import FreeThinker

final class DefaultSettingsServiceTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "freethinker.tests.settings.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testLoadSettingsReturnsDefaultWhenStoreEmpty() {
        let service = DefaultSettingsService(userDefaults: userDefaults)
        XCTAssertEqual(service.loadSettings(), AppSettings())
    }

    func testSaveAndLoadRoundTrip() throws {
        let service = DefaultSettingsService(userDefaults: userDefaults)
        let settings = AppSettings(
            hotkeyEnabled: false,
            dismissOnCopy: false,
            autoDismissSeconds: 12,
            fallbackCaptureEnabled: false,
            provocationStylePreset: .systemsThinking,
            customStyleInstructions: "Keep it concrete.",
            appUpdateChannel: .beta
        )

        try service.saveSettings(settings)
        let loaded = service.loadSettings()

        XCTAssertEqual(loaded.hotkeyEnabled, false)
        XCTAssertEqual(loaded.dismissOnCopy, false)
        XCTAssertEqual(loaded.autoDismissSeconds, 12)
        XCTAssertEqual(loaded.fallbackCaptureEnabled, false)
        XCTAssertEqual(loaded.provocationStylePreset, .systemsThinking)
        XCTAssertEqual(loaded.customStyleInstructions, "Keep it concrete.")
        XCTAssertEqual(loaded.appUpdateChannel, .beta)
    }

    func testLoadSettingsMigratesLegacyPayloadWithoutNewKeys() throws {
        let legacyJSON = """
        {
          "schemaVersion": 1,
          "hotkeyEnabled": true,
          "hotkeyModifiers": 1179648,
          "hotkeyKeyCode": 35,
          "prompt1": "Prompt A",
          "prompt2": "Prompt B",
          "launchAtLogin": false,
          "selectedModel": "default",
          "showMenuBarIcon": true,
          "dismissOnCopy": true,
          "provocationStylePreset": "socratic",
          "customStyleInstructions": "",
          "aiTimeoutSeconds": 5
        }
        """

        userDefaults.set(legacyJSON.data(using: .utf8), forKey: "freethinker.app_settings")
        let service = DefaultSettingsService(userDefaults: userDefaults)
        let loaded = service.loadSettings()

        XCTAssertEqual(loaded.schemaVersion, AppSettings.currentSchemaVersion)
        XCTAssertEqual(loaded.autoDismissSeconds, 6)
        XCTAssertEqual(loaded.fallbackCaptureEnabled, true)
        XCTAssertEqual(loaded.automaticallyCheckForUpdates, true)
        XCTAssertEqual(loaded.appUpdateChannel, .stable)
    }
}
