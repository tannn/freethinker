import XCTest
@testable import FreeThinker

@MainActor
final class GlobalHotkeyServiceTests: XCTestCase {
    func testRegisterSuccessAndTriggerCallback() throws {
        let registrar = MockGlobalHotkeyRegistrar()
        let service = GlobalHotkeyService(registrar: registrar)

        var triggerCount = 0
        service.onTrigger = {
            triggerCount += 1
        }

        try service.register(using: AppSettings(hotkeyEnabled: true, hotkeyKeyCode: 35))
        XCTAssertTrue(service.isRegistered)
        XCTAssertEqual(registrar.registerCalls, 1)

        registrar.simulateHotkeyPress(id: 1)
        XCTAssertEqual(triggerCount, 1)
    }

    func testRegisterConflictThrowsTypedErrorAndCallsErrorHandler() {
        let registrar = MockGlobalHotkeyRegistrar()
        registrar.registerError = .conflict

        let service = GlobalHotkeyService(registrar: registrar)
        var surfacedError: GlobalHotkeyServiceError?
        service.onRegistrationError = { surfacedError = $0 }

        XCTAssertThrowsError(try service.register(using: AppSettings())) { error in
            XCTAssertEqual(error as? GlobalHotkeyServiceError, .conflict)
        }

        XCTAssertEqual(surfacedError, .conflict)
        XCTAssertFalse(service.isRegistered)
    }

    func testRefreshRegistrationWithDisabledHotkeyUnregisters() {
        let registrar = MockGlobalHotkeyRegistrar()
        let service = GlobalHotkeyService(registrar: registrar)

        service.refreshRegistration(using: AppSettings(hotkeyEnabled: true))
        XCTAssertEqual(registrar.registerCalls, 1)

        service.refreshRegistration(using: AppSettings(hotkeyEnabled: false))
        XCTAssertEqual(registrar.unregisterCalls, 2)
        XCTAssertFalse(service.isRegistered)
    }

    func testUnregisterRemovesHandlerAndRegistration() throws {
        let registrar = MockGlobalHotkeyRegistrar()
        let service = GlobalHotkeyService(registrar: registrar)

        try service.register(using: AppSettings(hotkeyEnabled: true))
        service.unregister()

        XCTAssertEqual(registrar.unregisterCalls, 2)
        XCTAssertEqual(registrar.removeHandlerCalls, 2)
        XCTAssertFalse(service.isRegistered)
    }

    func testFR010_InvalidHotkeyProposalUsesValidatedFallbackKeyCode_SC04() {
        let registrar = MockGlobalHotkeyRegistrar()
        let service = GlobalHotkeyService(registrar: registrar)

        service.refreshRegistration(using: AppSettings(hotkeyEnabled: true, hotkeyKeyCode: 999))

        XCTAssertEqual(registrar.lastRegisterKeyCode, 35)
        XCTAssertTrue(service.isRegistered)
    }

    func testFR010_ConflictDuringRefreshDoesNotLeaveStaleRegistration_SC05() throws {
        let registrar = MockGlobalHotkeyRegistrar()
        let service = GlobalHotkeyService(registrar: registrar)

        try service.register(using: AppSettings(hotkeyEnabled: true, hotkeyKeyCode: 35))
        XCTAssertTrue(service.isRegistered)

        registrar.registerError = .conflict
        service.refreshRegistration(using: AppSettings(hotkeyEnabled: true, hotkeyKeyCode: 17))

        XCTAssertFalse(service.isRegistered)
        XCTAssertGreaterThanOrEqual(registrar.unregisterCalls, 2)
    }
}

private final class MockGlobalHotkeyRegistrar: GlobalHotkeyRegistering {
    private(set) var installCalls = 0
    private(set) var removeHandlerCalls = 0
    private(set) var registerCalls = 0
    private(set) var unregisterCalls = 0
    private(set) var lastRegisterID: UInt32?
    private(set) var lastRegisterKeyCode: UInt32?
    private(set) var lastRegisterModifiers: UInt32?

    var registerError: GlobalHotkeyServiceError?
    private var handler: ((UInt32) -> Void)?

    func installHandler(_ handler: @escaping (UInt32) -> Void) throws {
        installCalls += 1
        self.handler = handler
    }

    func removeHandler() {
        removeHandlerCalls += 1
        handler = nil
    }

    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32) throws {
        registerCalls += 1
        lastRegisterID = id
        lastRegisterKeyCode = keyCode
        lastRegisterModifiers = modifiers
        if let registerError {
            throw registerError
        }
    }

    func unregister(id: UInt32) {
        unregisterCalls += 1
    }

    func simulateHotkeyPress(id: UInt32) {
        handler?(id)
    }
}
