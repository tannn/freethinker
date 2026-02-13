import Foundation

public enum FreeThinkerError: Error, Equatable, Sendable {
    case permissionDenied(status: PermissionStatus)
    case permissionPromptSuppressed(until: Date?)
    case noFocusedElement
    case noSelection
    case unsupportedElement(role: String?)
    case clipboardCaptureTimedOut
    case fallbackDisabled
    case captureFailed(reason: String)
    case cancelled

    public var userMessage: String {
        switch self {
        case .permissionDenied:
            return "Accessibility permission is required to capture selected text."
        case .permissionPromptSuppressed:
            return "Permission prompt was recently shown. Try again in a moment or open System Settings."
        case .noFocusedElement:
            return "No focused text element was found."
        case .noSelection:
            return "No text is currently selected."
        case .unsupportedElement:
            return "The focused element does not support text selection capture."
        case .clipboardCaptureTimedOut:
            return "Timed out waiting for copied text from the clipboard fallback path."
        case .fallbackDisabled:
            return "Clipboard fallback capture is disabled."
        case .captureFailed:
            return "Text capture failed. Please try again."
        case .cancelled:
            return "Text capture was cancelled."
        }
    }
}
