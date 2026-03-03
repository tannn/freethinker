import Foundation

/// Canonical error type for all recoverable and unrecoverable failures in FreeThinker.
///
/// All public async APIs either throw or encode `FreeThinkerError` values into their return types.
/// Use ``userMessage`` to obtain a localised string suitable for display in the UI, and
/// ``isRetriable`` to determine whether the operation is worth retrying automatically.
public enum FreeThinkerError: Error, Sendable, Equatable {
    /// The app does not have Accessibility permission required to read selected text.
    case accessibilityPermissionDenied

    /// The user triggered a generation but no text was selected in the active app.
    case noSelection

    /// The proposed hotkey shortcut is structurally invalid (e.g., no modifier key).
    case hotkeyShortcutInvalid

    /// The proposed hotkey shortcut is reserved by macOS and cannot be registered.
    case hotkeyShortcutReserved

    /// The proposed hotkey shortcut is already claimed by another application.
    case hotkeyRegistrationConflict

    /// The hotkey shortcut could not be registered for an unspecified system reason.
    case hotkeyRegistrationFailed

    /// AI generation exceeded the configured timeout duration.
    case timeout

    /// Generation was cancelled by the user or a competing trigger.
    case cancelled

    /// The configured AI model is not available on this device or OS version.
    case modelUnavailable

    /// The macOS version is too old to support on-device Foundation Models.
    case unsupportedOperatingSystem

    /// The device hardware (e.g., Intel Mac) cannot run on-device AI models.
    case unsupportedHardware

    /// The FoundationModels framework is absent from this build configuration.
    case frameworkUnavailable

    /// The model returned a transient failure and may succeed if retried shortly.
    case transientModelFailure

    /// Generation failed for an unspecified or unexpected reason.
    case generationFailed

    /// The composed prompt was rejected before being sent to the model.
    case invalidPrompt

    /// The model's raw output could not be parsed into a valid ``ProvocationContent``.
    case invalidResponse

    /// The trigger arrived within the debounce window and was silently ignored.
    case triggerDebounced

    /// A generation pipeline is already running and the new trigger was rejected.
    case generationAlreadyInProgress
}

extension FreeThinkerError: LocalizedError {
    public var errorDescription: String? {
        userMessage
    }
}

public extension FreeThinkerError {
    /// A localised string describing the error in terms suitable for end-user display.
    var userMessage: String {
        switch self {
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required to read selected text."
        case .noSelection:
            return "No text selected. Select text and try again."
        case .hotkeyShortcutInvalid:
            return "That shortcut is not supported."
        case .hotkeyShortcutReserved:
            return "That shortcut is reserved by macOS."
        case .hotkeyRegistrationConflict:
            return "The global hotkey is already used by another app."
        case .hotkeyRegistrationFailed:
            return "Could not register the global hotkey."
        case .timeout:
            return "AI generation timed out. Please try again."
        case .cancelled:
            return "Generation was cancelled."
        case .modelUnavailable:
            return "AI model is unavailable. Check system requirements."
        case .unsupportedOperatingSystem:
            return "FreeThinker requires macOS 26 or later for on-device AI."
        case .unsupportedHardware:
            return "FreeThinker requires Apple Silicon for on-device AI."
        case .frameworkUnavailable:
            return "The FoundationModels framework is unavailable in this build."
        case .transientModelFailure:
            return "The AI model is warming up. Please try again."
        case .generationFailed:
            return "Could not generate provocations. Please try again."
        case .invalidPrompt:
            return "The generated prompt was invalid."
        case .invalidResponse:
            return "The AI response format was invalid."
        case .triggerDebounced:
            return "Trigger ignored because it was pressed too quickly."
        case .generationAlreadyInProgress:
            return "A provocation is already being generated."
        }
    }

    /// `true` for errors that are likely transient and worth retrying automatically.
    ///
    /// Currently only ``transientModelFailure`` is retriable.
    var isRetriable: Bool {
        switch self {
        case .transientModelFailure:
            return true
        default:
            return false
        }
    }
}
