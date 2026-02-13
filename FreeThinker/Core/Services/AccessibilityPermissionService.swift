import AppKit
import ApplicationServices
import Foundation

public protocol AccessibilityPermissionServiceProtocol: Sendable {
    func currentStatus() async -> PermissionStatus
    func requestPermissionIfNeeded() async -> PermissionStatus
    func openSystemSettings() async -> Bool
}

public protocol AccessibilityTrustChecking: Sendable {
    func isProcessTrusted(prompt: Bool) -> Bool
}

public struct SystemAccessibilityTrustChecker: AccessibilityTrustChecking {
    public init() {}

    public func isProcessTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

public protocol URLOpening: Sendable {
    @discardableResult
    func open(_ url: URL) -> Bool
}

public struct WorkspaceURLOpener: URLOpening {
    public init() {}

    @discardableResult
    public func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}

public protocol DateProviding: Sendable {
    var now: Date { get }
}

public struct SystemDateProvider: DateProviding {
    public init() {}

    public var now: Date { Date() }
}

public actor AccessibilityPermissionService: AccessibilityPermissionServiceProtocol {
    public static let defaultPromptCooldown: TimeInterval = 30

    private let trustChecker: AccessibilityTrustChecking
    private let urlOpener: URLOpening
    private let dateProvider: DateProviding
    private let promptCooldown: TimeInterval
    private let userDefaults: UserDefaults
    private let promptDateKey: String
    private let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    private var lastPromptDate: Date?

    public init(
        trustChecker: AccessibilityTrustChecking = SystemAccessibilityTrustChecker(),
        urlOpener: URLOpening = WorkspaceURLOpener(),
        dateProvider: DateProviding = SystemDateProvider(),
        userDefaults: UserDefaults = .standard,
        promptCooldown: TimeInterval = AccessibilityPermissionService.defaultPromptCooldown,
        promptDateKey: String = "com.freethinker.accessibility.lastPromptDate"
    ) {
        self.trustChecker = trustChecker
        self.urlOpener = urlOpener
        self.dateProvider = dateProvider
        self.userDefaults = userDefaults
        self.promptCooldown = promptCooldown
        self.promptDateKey = promptDateKey
        self.lastPromptDate = userDefaults.object(forKey: promptDateKey) as? Date
    }

    public func currentStatus() async -> PermissionStatus {
        if trustChecker.isProcessTrusted(prompt: false) {
            return .authorized
        }

        let now = dateProvider.now
        let nextPromptDate = lastPromptDate.map { $0.addingTimeInterval(promptCooldown) }
        let canPrompt = nextPromptDate.map { now >= $0 } ?? true
        return .denied(canPrompt: canPrompt, nextPromptDate: nextPromptDate)
    }

    public func requestPermissionIfNeeded() async -> PermissionStatus {
        let status = await currentStatus()
        guard !status.isAuthorized else {
            return status
        }

        guard case let .denied(canPrompt, nextPromptDate) = status else {
            return status
        }

        guard canPrompt else {
            return .denied(canPrompt: false, nextPromptDate: nextPromptDate)
        }

        _ = trustChecker.isProcessTrusted(prompt: true)

        let now = dateProvider.now
        lastPromptDate = now
        userDefaults.set(now, forKey: promptDateKey)

        return await currentStatus()
    }

    public func openSystemSettings() async -> Bool {
        urlOpener.open(settingsURL)
    }
}
