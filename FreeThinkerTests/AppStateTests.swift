import XCTest
@testable import FreeThinker

@MainActor
final class AppStateTests: XCTestCase {
    func testLoadIfNeededPopulatesSettingsAndDerivedProperties() async {
        var loadedSettings = AppSettings.defaultValue
        loadedSettings.provocationStyle = .provocative
        loadedSettings.launchAtLogin = true

        let settingsService = MockSettingsService(loadResult: .success(loadedSettings))
        let launchService = MockLaunchAtLoginService(statusResult: .success(.enabled))
        let appState = AppState(settingsService: settingsService, launchAtLoginService: launchService)

        await appState.loadIfNeeded()

        XCTAssertEqual(appState.settingsLoadState, .loaded)
        XCTAssertEqual(appState.settings, loadedSettings)
        XCTAssertEqual(appState.selectedStyle, .provocative)
        XCTAssertEqual(appState.launchAtLoginEnabled, true)
    }

    func testSetPanelBehaviorPersistsAndUpdatesInMemoryState() async {
        let settingsService = MockSettingsService(loadResult: .success(.defaultValue))
        let launchService = MockLaunchAtLoginService(statusResult: .success(.disabled))
        let appState = AppState(settingsService: settingsService, launchAtLoginService: launchService)

        await appState.loadIfNeeded()
        await appState.setPanelBehavior(.pinned)

        XCTAssertEqual(appState.settings.panelBehavior, .pinned)
        let persistedSettings = await settingsService.lastSavedSettings
        XCTAssertEqual(persistedSettings?.panelBehavior, .pinned)
    }

    func testSetLaunchAtLoginPersistsWhenServicesSucceed() async {
        let settingsService = MockSettingsService(loadResult: .success(.defaultValue))
        let launchService = MockLaunchAtLoginService(
            statusResult: .success(.disabled),
            enableResult: .success(())
        )
        let appState = AppState(settingsService: settingsService, launchAtLoginService: launchService)

        await appState.loadIfNeeded()
        await appState.setLaunchAtLogin(true)

        XCTAssertEqual(appState.settings.launchAtLogin, true)
        let persistedSettings = await settingsService.lastSavedSettings
        XCTAssertEqual(persistedSettings?.launchAtLogin, true)
    }

    func testSetLaunchAtLoginKeepsStateWhenLaunchServiceFails() async {
        let settingsService = MockSettingsService(loadResult: .success(.defaultValue))
        let launchService = MockLaunchAtLoginService(
            statusResult: .success(.disabled),
            enableResult: .failure(.enableFailed(details: "no permission"))
        )
        let appState = AppState(settingsService: settingsService, launchAtLoginService: launchService)

        await appState.loadIfNeeded()
        await appState.setLaunchAtLogin(true)

        XCTAssertEqual(appState.settings.launchAtLogin, false)

        guard case let .launchAtLogin(error)? = appState.lastError else {
            XCTFail("Expected launch-at-login error")
            return
        }

        XCTAssertEqual(error, .enableFailed(details: "no permission"))
    }

    func testSetLaunchAtLoginRollsBackSystemStateWhenSettingsSaveFails() async {
        let settingsService = MockSettingsService(
            loadResult: .success(.defaultValue),
            saveResult: .failure(.persistenceFailed(details: "disk full"))
        )
        let launchService = MockLaunchAtLoginService(
            statusResult: .success(.disabled),
            enableResult: .success(()),
            disableResult: .success(())
        )
        let appState = AppState(settingsService: settingsService, launchAtLoginService: launchService)

        await appState.loadIfNeeded()
        await appState.setLaunchAtLogin(true)

        XCTAssertEqual(appState.settings.launchAtLogin, false)
        let calls = await launchService.setEnabledCalls
        XCTAssertEqual(calls, [true, false])
    }

    func testLoadSynchronizesLaunchAtLoginWhenSystemStateDiffers() async {
        var loadedSettings = AppSettings.defaultValue
        loadedSettings.launchAtLogin = false

        let settingsService = MockSettingsService(loadResult: .success(loadedSettings))
        let launchService = MockLaunchAtLoginService(statusResult: .success(.enabled))
        let appState = AppState(settingsService: settingsService, launchAtLoginService: launchService)

        await appState.loadIfNeeded()

        XCTAssertEqual(appState.settings.launchAtLogin, true)
        let persistedSettings = await settingsService.lastSavedSettings
        XCTAssertEqual(persistedSettings?.launchAtLogin, true)
    }
}

private actor MockSettingsService: SettingsService {
    private let configuredLoadResult: Result<AppSettings, SettingsServiceError>
    private let configuredSaveResult: Result<Void, SettingsServiceError>
    private let configuredResetResult: Result<AppSettings, SettingsServiceError>

    private(set) var savedSettingsHistory: [AppSettings] = []

    var lastSavedSettings: AppSettings? {
        savedSettingsHistory.last
    }

    init(
        loadResult: Result<AppSettings, SettingsServiceError>,
        saveResult: Result<Void, SettingsServiceError> = .success(()),
        resetResult: Result<AppSettings, SettingsServiceError> = .success(.defaultValue)
    ) {
        configuredLoadResult = loadResult
        configuredSaveResult = saveResult
        configuredResetResult = resetResult
    }

    func load() async -> Result<AppSettings, SettingsServiceError> {
        configuredLoadResult
    }

    func save(_ settings: AppSettings) async -> Result<Void, SettingsServiceError> {
        savedSettingsHistory.append(settings)
        return configuredSaveResult
    }

    func resetToDefaults(preservingLaunchAtLogin: Bool) async -> Result<AppSettings, SettingsServiceError> {
        configuredResetResult
    }
}

private actor MockLaunchAtLoginService: LaunchAtLoginService {
    private let configuredStatusResult: Result<LaunchAtLoginStatus, LaunchAtLoginServiceError>
    private let configuredEnableResult: Result<Void, LaunchAtLoginServiceError>
    private let configuredDisableResult: Result<Void, LaunchAtLoginServiceError>
    private(set) var setEnabledCalls: [Bool] = []

    init(
        statusResult: Result<LaunchAtLoginStatus, LaunchAtLoginServiceError>,
        enableResult: Result<Void, LaunchAtLoginServiceError> = .success(()),
        disableResult: Result<Void, LaunchAtLoginServiceError> = .success(())
    ) {
        configuredStatusResult = statusResult
        configuredEnableResult = enableResult
        configuredDisableResult = disableResult
    }

    func status() async -> Result<LaunchAtLoginStatus, LaunchAtLoginServiceError> {
        configuredStatusResult
    }

    func setEnabled(_ enabled: Bool) async -> Result<Void, LaunchAtLoginServiceError> {
        setEnabledCalls.append(enabled)
        if enabled {
            return configuredEnableResult
        }
        return configuredDisableResult
    }
}
