import AppKit
import ApplicationServices
import Foundation

public enum TextCapturePermissionStatus: Equatable, Sendable {
    case granted
    case denied
}

public protocol TextCaptureServiceProtocol: Actor, Sendable {
    func preflightPermission() -> TextCapturePermissionStatus
    func setFallbackCaptureEnabled(_ isEnabled: Bool)
    func captureSelectedText() async throws -> String
}

public actor DefaultTextCaptureService: TextCaptureServiceProtocol {
    private let maxSelectionLength: Int
    private let permissionChecker: @Sendable () -> Bool
    private let accessibilityReachabilityProbe: @Sendable () -> Bool
    private let accessibilitySelectionProvider: @Sendable () -> String?
    private let clipboardFallbackProvider: @Sendable () -> String?
    private var fallbackCaptureEnabled: Bool

    public init(
        maxSelectionLength: Int = ProvocationRequest.maxSelectedTextLength,
        fallbackCaptureEnabled: Bool = true,
        permissionChecker: (@Sendable () -> Bool)? = nil,
        accessibilityReachabilityProbe: (@Sendable () -> Bool)? = nil,
        accessibilitySelectionProvider: (@Sendable () -> String?)? = nil,
        clipboardFallbackProvider: (@Sendable () -> String?)? = nil
    ) {
        self.maxSelectionLength = maxSelectionLength
        self.fallbackCaptureEnabled = fallbackCaptureEnabled
        self.permissionChecker = permissionChecker ?? { AXIsProcessTrusted() }
        self.accessibilityReachabilityProbe = accessibilityReachabilityProbe ?? {
            Self.isAccessibilityAPIReachable()
        }
        self.accessibilitySelectionProvider = accessibilitySelectionProvider ?? {
            Self.captureAccessibilitySelectedText()
        }
        self.clipboardFallbackProvider = clipboardFallbackProvider ?? {
            NSPasteboard.general.string(forType: .string)
        }
    }

    public func preflightPermission() -> TextCapturePermissionStatus {
        (permissionChecker() || accessibilityReachabilityProbe()) ? .granted : .denied
    }

    public func setFallbackCaptureEnabled(_ isEnabled: Bool) {
        fallbackCaptureEnabled = isEnabled
    }

    public func captureSelectedText() async throws -> String {
        try Task.checkCancellation()

        guard preflightPermission() == .granted else {
            Logger.warning("Selection capture blocked: accessibility permission denied", category: .textCapture)
            throw FreeThinkerError.accessibilityPermissionDenied
        }

        if let captured = normalizedSelection(from: accessibilitySelectionProvider()) {
            Logger.debug("Selection captured via accessibility characters=\(captured.count)", category: .textCapture)
            return String(captured.prefix(maxSelectionLength))
        }

        if fallbackCaptureEnabled, let captured = normalizedSelection(from: clipboardFallbackProvider()) {
            Logger.info("Selection captured via clipboard fallback", category: .textCapture)
            return String(captured.prefix(maxSelectionLength))
        }

        try Task.checkCancellation()

        Logger.info("Selection capture yielded no text", category: .textCapture)
        throw FreeThinkerError.noSelection
    }
}

private extension DefaultTextCaptureService {
    func normalizedSelection(from rawSelection: String?) -> String? {
        guard let rawSelection else {
            return nil
        }

        let trimmed = rawSelection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }

    static func captureAccessibilitySelectedText() -> String? {
        let systemWideElement = AXUIElementCreateSystemWide()

        var focusedElementRef: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )

        guard
            focusedStatus == .success,
            let focusedElementRef,
            CFGetTypeID(focusedElementRef) == AXUIElementGetTypeID()
        else {
            return nil
        }

        let focusedElement = unsafeBitCast(focusedElementRef, to: AXUIElement.self)

        var selectedTextRef: CFTypeRef?
        let selectedTextStatus = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &selectedTextRef
        )

        guard selectedTextStatus == .success, let selectedTextRef else {
            return nil
        }

        if let selectedText = selectedTextRef as? String {
            return selectedText
        }

        if let attributedText = selectedTextRef as? NSAttributedString {
            return attributedText.string
        }

        return nil
    }

    static func isAccessibilityAPIReachable() -> Bool {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElementRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )

        return status != .apiDisabled
    }
}
