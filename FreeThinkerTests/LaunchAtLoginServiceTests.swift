import XCTest
@testable import FreeThinker

final class LaunchAtLoginServiceTests: XCTestCase {
    func testEnableIsIdempotentWhenAlreadyEnabled() async {
        let client = MockLaunchAtLoginClient(statusResponses: [.enabled])
        let service = DefaultLaunchAtLoginService(client: client)

        let result = await service.setEnabled(true)

        XCTAssertTrue(result.isSuccess)
        let registerCalls = await client.registerCallCount
        XCTAssertEqual(registerCalls, 0)
    }

    func testDisableIsIdempotentWhenAlreadyDisabled() async {
        let client = MockLaunchAtLoginClient(statusResponses: [.disabled])
        let service = DefaultLaunchAtLoginService(client: client)

        let result = await service.setEnabled(false)

        XCTAssertTrue(result.isSuccess)
        let unregisterCalls = await client.unregisterCallCount
        XCTAssertEqual(unregisterCalls, 0)
    }

    func testEnableRegistersAndVerifiesFinalState() async {
        let client = MockLaunchAtLoginClient(statusResponses: [.disabled, .enabled])
        let service = DefaultLaunchAtLoginService(client: client)

        let result = await service.setEnabled(true)

        XCTAssertTrue(result.isSuccess)
        let registerCalls = await client.registerCallCount
        XCTAssertEqual(registerCalls, 1)
    }

    func testEnableMapsUnderlyingRegisterFailure() async {
        let client = MockLaunchAtLoginClient(
            statusResponses: [.disabled],
            registerError: MockError(message: "register failed")
        )
        let service = DefaultLaunchAtLoginService(client: client)

        let result = await service.setEnabled(true)

        switch result {
        case .success:
            XCTFail("Expected failure")
        case let .failure(error):
            guard case let .enableFailed(details) = error else {
                XCTFail("Expected enable failure")
                return
            }

            XCTAssertTrue(details.contains("register failed"))
            XCTAssertTrue(details.contains("MockError"))
        }
    }

    func testSetEnabledDetectsStateMismatch() async {
        let client = MockLaunchAtLoginClient(statusResponses: [.disabled, .disabled])
        let service = DefaultLaunchAtLoginService(client: client)

        let result = await service.setEnabled(true)

        switch result {
        case .success:
            XCTFail("Expected mismatch failure")
        case let .failure(error):
            XCTAssertEqual(error, .stateMismatch(expectedEnabled: true, actual: .disabled))
        }
    }

    func testStatusReportsCurrentClientStatus() async {
        let client = MockLaunchAtLoginClient(statusResponses: [.requiresApproval])
        let service = DefaultLaunchAtLoginService(client: client)

        let result = await service.status()

        switch result {
        case let .success(status):
            XCTAssertEqual(status, .requiresApproval)
        case let .failure(error):
            XCTFail("Expected status success, got: \(error)")
        }
    }

    func testEnableTreatsFailureAsSuccessWhenStatusAlreadyUpdated() async {
        let client = MockLaunchAtLoginClient(
            statusResponses: [.disabled, .enabled],
            registerError: MockError(message: "register failed after update")
        )
        let service = DefaultLaunchAtLoginService(client: client)

        let result = await service.setEnabled(true)

        XCTAssertTrue(result.isSuccess)
    }

    func testDisableMapsUnderlyingUnregisterFailure() async {
        let client = MockLaunchAtLoginClient(
            statusResponses: [.enabled, .enabled],
            unregisterError: MockError(message: "unregister failed")
        )
        let service = DefaultLaunchAtLoginService(client: client)

        let result = await service.setEnabled(false)

        switch result {
        case .success:
            XCTFail("Expected failure")
        case let .failure(error):
            guard case let .disableFailed(details) = error else {
                XCTFail("Expected disable failure")
                return
            }

            XCTAssertTrue(details.contains("unregister failed"))
        }
    }
}

private actor MockLaunchAtLoginClient: LaunchAtLoginClient {
    private var statusResponses: [LaunchAtLoginStatus]
    private var statusIndex = 0

    private let registerFailure: MockError?
    private let unregisterFailure: MockError?

    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0

    init(
        statusResponses: [LaunchAtLoginStatus],
        registerError: MockError? = nil,
        unregisterError: MockError? = nil
    ) {
        self.statusResponses = statusResponses.isEmpty ? [.disabled] : statusResponses
        registerFailure = registerError
        unregisterFailure = unregisterError
    }

    func currentStatus() async throws -> LaunchAtLoginStatus {
        let resolvedStatus = statusResponses[min(statusIndex, statusResponses.count - 1)]
        statusIndex += 1
        return resolvedStatus
    }

    func register() async throws {
        registerCallCount += 1
        if let registerFailure {
            throw registerFailure
        }
    }

    func unregister() async throws {
        unregisterCallCount += 1
        if let unregisterFailure {
            throw unregisterFailure
        }
    }
}

private struct MockError: Error, LocalizedError, Sendable {
    let message: String

    var errorDescription: String? {
        message
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
