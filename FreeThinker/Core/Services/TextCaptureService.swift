import Foundation

public protocol TextCaptureServiceProtocol: Sendable {
    var hasAccessibilityPermission: Bool { get async }
    func preflightPermission(promptIfNeeded: Bool) async -> PermissionStatus
    func requestAccessibilityPermission() async -> PermissionStatus
    func openAccessibilitySettings() async -> Bool
    func captureSelectedText() async throws -> CaptureResult
}
