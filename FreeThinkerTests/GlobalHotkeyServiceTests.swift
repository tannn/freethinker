import AppKit
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

    func testValidateShortcutProposalRejectsMissingModifiersWithoutProbe() {
        let registrar = MockGlobalHotkeyRegistrar()
        let service = GlobalHotkeyService(registrar: registrar)
        let current = AppSettings().hotkeyShortcut
        let proposed = HotkeyShortcut(modifiers: 0, keyCode: 35)

        let result = service.validateShortcutProposal(proposed, effectiveShortcut: current)

        XCTAssertEqual(result.status, .invalid)
        XCTAssertEqual(result.effectiveShortcut, current)
        XCTAssertEqual(registrar.registerCalls, 0)
    }

    func testValidateShortcutProposalRejectsReservedShortcutWithoutProbe() {
        let registrar = MockGlobalHotkeyRegistrar()
        let service = GlobalHotkeyService(registrar: registrar)
        let current = AppSettings().hotkeyShortcut
        let reserved = HotkeyShortcut(
            modifiers: Int(NSEvent.ModifierFlags.command.rawValue),
            keyCode: 12 // Q
        )

        let result = service.validateShortcutProposal(reserved, effectiveShortcut: current)

        XCTAssertEqual(result.status, .reserved)
        XCTAssertEqual(result.effectiveShortcut, current)
        XCTAssertEqual(registrar.registerCalls, 0)
    }

    func testValidateShortcutProposalClassifiesConflictAndKeepsEffectiveShortcut() {
        let registrar = MockGlobalHotkeyRegistrar()
        registrar.registerError = .conflict
        let service = GlobalHotkeyService(registrar: registrar)
        let current = AppSettings().hotkeyShortcut
        let proposed = HotkeyShortcut(
            modifiers: AppSettings.defaultHotkeyModifiers,
            keyCode: 40 // K
        )

        let result = service.validateShortcutProposal(proposed, effectiveShortcut: current)

        XCTAssertEqual(result.status, .conflict)
        XCTAssertEqual(result.effectiveShortcut, current)
        XCTAssertEqual(registrar.registerCalls, 1)
    }

    func testValidateShortcutProposalReturnsValidAndUsesProposedEffectiveShortcut() {
        let registrar = MockGlobalHotkeyRegistrar()
        let service = GlobalHotkeyService(registrar: registrar)
        let current = AppSettings().hotkeyShortcut
        let proposed = HotkeyShortcut(
            modifiers: AppSettings.defaultHotkeyModifiers,
            keyCode: 40 // K
        )

        let result = service.validateShortcutProposal(proposed, effectiveShortcut: current)

        XCTAssertEqual(result.status, .valid)
        XCTAssertEqual(result.effectiveShortcut, proposed)
        XCTAssertEqual(registrar.registerCalls, 1)
        XCTAssertEqual(registrar.unregisterCalls, 1)
    }

    func testRegisterConflictAfterExistingRegistrationKeepsCurrentRegistration() throws {
        let registrar = MockGlobalHotkeyRegistrar()
        let service = GlobalHotkeyService(registrar: registrar)

        try service.register(using: AppSettings(hotkeyEnabled: true))
        registrar.registerError = .conflict

        XCTAssertThrowsError(
            try service.register(
                using: AppSettings(
                    hotkeyEnabled: true,
                    hotkeyModifiers: AppSettings.defaultHotkeyModifiers,
                    hotkeyKeyCode: 40 // K
                )
            )
        ) { error in
            XCTAssertEqual(error as? GlobalHotkeyServiceError, .conflict)
        }

        XCTAssertTrue(service.isRegistered)
        XCTAssertEqual(registrar.unregisterCalls, 1)
    }

    func testRegisterFailureAfterValidationRestoresPreviousShortcut() throws {
        let registrar = MockGlobalHotkeyRegistrar()
        let service = GlobalHotkeyService(registrar: registrar)
        var triggerCount = 0
        service.onTrigger = { triggerCount += 1 }

        try service.register(using: AppSettings(hotkeyEnabled: true))

        let originalRegisterCallCount = registrar.registerCalls
        registrar.registerErrorProvider = { id, callIndex in
            // Fail only the first non-probe register attempt for the updated shortcut.
            if id == 1, callIndex == originalRegisterCallCount + 2 {
                return .conflict
            }
            return nil
        }

        XCTAssertThrowsError(
            try service.register(
                using: AppSettings(
                    hotkeyEnabled: true,
                    hotkeyModifiers: AppSettings.defaultHotkeyModifiers,
                    hotkeyKeyCode: 40
                )
            )
        ) { error in
            XCTAssertEqual(error as? GlobalHotkeyServiceError, .conflict)
        }

        XCTAssertTrue(service.isRegistered)
        registrar.simulateHotkeyPress(id: 1)
        XCTAssertEqual(triggerCount, 1)
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

    func testFR010_ConflictDuringRefreshKeepsPreviousRegistrationActive_SC05() throws {
        let registrar = MockGlobalHotkeyRegistrar()
        let service = GlobalHotkeyService(registrar: registrar)

        try service.register(using: AppSettings(hotkeyEnabled: true, hotkeyKeyCode: 35))
        XCTAssertTrue(service.isRegistered)

        registrar.registerError = .conflict
        service.refreshRegistration(using: AppSettings(hotkeyEnabled: true, hotkeyKeyCode: 17))

        XCTAssertTrue(service.isRegistered)
        XCTAssertEqual(registrar.unregisterCalls, 1)
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
    var registerErrorProvider: ((UInt32, Int) -> GlobalHotkeyServiceError?)?
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
        if let registerError = registerErrorProvider?(id, registerCalls) {
            throw registerError
        }
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
