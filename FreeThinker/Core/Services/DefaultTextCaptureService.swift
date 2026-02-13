import AppKit
import ApplicationServices
import Foundation

public enum TextCapturePermissionStatus: Equatable, Sendable {
    case granted
    case denied
}

public protocol TextCaptureServiceProtocol: Actor, Sendable {
    func preflightPermission() -> TextCapturePermissionStatus
    func captureSelectedText() async throws -> String
}

public actor DefaultTextCaptureService: TextCaptureServiceProtocol {
    private let maxSelectionLength: Int
    private let permissionChecker: @Sendable () -> Bool
    private let selectedTextProvider: @Sendable () -> String?

    public init(
        maxSelectionLength: Int = ProvocationRequest.maxSelectedTextLength,
        permissionChecker: (@Sendable () -> Bool)? = nil,
        selectedTextProvider: (@Sendable () -> String?)? = nil
    ) {
        self.maxSelectionLength = maxSelectionLength
        self.permissionChecker = permissionChecker ?? { AXIsProcessTrusted() }
        self.selectedTextProvider = selectedTextProvider ?? {
            NSPasteboard.general.string(forType: .string)
        }
    }

    public func preflightPermission() -> TextCapturePermissionStatus {
        permissionChecker() ? .granted : .denied
    }

    public func captureSelectedText() async throws -> String {
        try Task.checkCancellation()

        guard preflightPermission() == .granted else {
            Logger.warning("Selection capture blocked: accessibility permission denied", category: .textCapture)
            throw FreeThinkerError.accessibilityPermissionDenied
        }

        let trimmed = selectedTextProvider()?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        try Task.checkCancellation()

        guard !trimmed.isEmpty else {
            Logger.info("Selection capture yielded no text", category: .textCapture)
            throw FreeThinkerError.noSelection
        }

        let captured = String(trimmed.prefix(maxSelectionLength))
        Logger.debug("Selection captured characters=\(captured.count)", category: .textCapture)
        return captured
    }
}
