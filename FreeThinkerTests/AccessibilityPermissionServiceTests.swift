import Foundation
import XCTest
@testable import FreeThinker

final class AccessibilityPermissionServiceTests: XCTestCase {
    func testCurrentStatusReturnsAuthorizedWhenTrusted() async {
        let trustChecker = MockTrustChecker()
        trustChecker.isTrustedWithoutPrompt = true

        let service = AccessibilityPermissionService(
            trustChecker: trustChecker,
            urlOpener: MockURLOpener(),
            dateProvider: MutableDateProvider(now: Date()),
            userDefaults: makeUserDefaults(),
            promptCooldown: 30,
            promptDateKey: UUID().uuidString
        )

        let status = await service.currentStatus()
        XCTAssertEqual(status, .authorized)
    }

    func testRequestPermissionDoesNotPromptInsideCooldown() async {
        let trustChecker = MockTrustChecker()
        trustChecker.isTrustedWithoutPrompt = false

        let now = Date(timeIntervalSince1970: 1_000)
        let dateProvider = MutableDateProvider(now: now)
        let userDefaults = makeUserDefaults()
        let promptDateKey = UUID().uuidString

        let service = AccessibilityPermissionService(
            trustChecker: trustChecker,
            urlOpener: MockURLOpener(),
            dateProvider: dateProvider,
            userDefaults: userDefaults,
            promptCooldown: 60,
            promptDateKey: promptDateKey
        )

        _ = await service.requestPermissionIfNeeded()
        XCTAssertEqual(trustChecker.promptCallCount, 1)

        dateProvider.now = now.addingTimeInterval(10)
        let secondStatus = await service.requestPermissionIfNeeded()

        XCTAssertEqual(trustChecker.promptCallCount, 1)
        XCTAssertEqual(secondStatus, .denied(canPrompt: false, nextPromptDate: now.addingTimeInterval(60)))
    }

    func testRequestPermissionPromptsAgainAfterCooldownExpires() async {
        let trustChecker = MockTrustChecker()
        trustChecker.isTrustedWithoutPrompt = false

        let now = Date(timeIntervalSince1970: 2_000)
        let dateProvider = MutableDateProvider(now: now)

        let service = AccessibilityPermissionService(
            trustChecker: trustChecker,
            urlOpener: MockURLOpener(),
            dateProvider: dateProvider,
            userDefaults: makeUserDefaults(),
            promptCooldown: 5,
            promptDateKey: UUID().uuidString
        )

        _ = await service.requestPermissionIfNeeded()
        XCTAssertEqual(trustChecker.promptCallCount, 1)

        dateProvider.now = now.addingTimeInterval(6)
        _ = await service.requestPermissionIfNeeded()
        XCTAssertEqual(trustChecker.promptCallCount, 2)
    }

    func testOpenSystemSettingsUsesExpectedURL() async {
        let opener = MockURLOpener()
        let service = AccessibilityPermissionService(
            trustChecker: MockTrustChecker(),
            urlOpener: opener,
            dateProvider: MutableDateProvider(now: Date()),
            userDefaults: makeUserDefaults(),
            promptCooldown: 30,
            promptDateKey: UUID().uuidString
        )

        let didOpen = await service.openSystemSettings()

        XCTAssertTrue(didOpen)
        XCTAssertEqual(
            opener.lastOpenedURL?.absoluteString,
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "AccessibilityPermissionServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private final class MockTrustChecker: AccessibilityTrustChecking, @unchecked Sendable {
    var isTrustedWithoutPrompt = false
    var promptResponse = false
    private(set) var promptCallCount = 0

    func isProcessTrusted(prompt: Bool) -> Bool {
        if prompt {
            promptCallCount += 1
            return promptResponse
        }
        return isTrustedWithoutPrompt
    }
}

private final class MutableDateProvider: DateProviding, @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

private final class MockURLOpener: URLOpening, @unchecked Sendable {
    private(set) var lastOpenedURL: URL?

    @discardableResult
    func open(_ url: URL) -> Bool {
        lastOpenedURL = url
        return true
    }
}
