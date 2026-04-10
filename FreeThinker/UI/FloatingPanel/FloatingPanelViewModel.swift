import AppKit
import Combine
import Foundation

/// Protocol abstracting sleep timing for testability in ``FloatingPanelViewModel``.
public protocol FloatingPanelTiming: Sendable {
    /// Suspends the current task for the given number of nanoseconds.
    ///
    /// - Parameter nanoseconds: The sleep duration.
    /// - Throws: `CancellationError` if the task is cancelled.
    func sleep(nanoseconds: UInt64) async throws
}

/// The default timing implementation backed by `Task.sleep`.
public struct SystemFloatingPanelTiming: FloatingPanelTiming {
    /// Creates the system timing provider.
    public init() {}

    /// Suspends using `Task.sleep(nanoseconds:)`.
    public func sleep(nanoseconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

/// Observable view model for the floating provocation panel.
///
/// `FloatingPanelViewModel` is `@MainActor`-isolated and drives the panel's SwiftUI
/// views. It manages the UI state machine, auto-dismiss timers, copy-feedback animations,
/// pin state, and regenerate requests.
@MainActor
public final class FloatingPanelViewModel: ObservableObject {
    /// The panel's UI state machine.
    public enum State: Equatable {
        /// The panel is hidden or in its initial resting state.
        case idle
        /// A generation is in progress; an optional text preview may be shown.
        case loading(selectedTextPreview: String?)
        /// Generation succeeded; the panel shows the provocation response.
        case success(response: ProvocationResponse)
        /// Generation failed or was rejected; the panel shows an error message.
        case error(message: String)
    }

    /// The current UI state. Drives the panel's displayed content.
    @Published public private(set) var state: State = .idle
    /// Whether the panel is pinned and therefore exempt from auto-dismiss.
    @Published public private(set) var isPinned: Bool
    /// `true` while a regeneration request is in flight.
    @Published public private(set) var isRegenerating: Bool = false
    /// Transient copy confirmation text shown briefly after the user copies a result.
    @Published public private(set) var copyFeedback: String?
    /// A suggested remediation action shown alongside the error message, or `nil`.
    @Published public private(set) var suggestedAction: ErrorPresentationAction?
    /// The display name of the currently active provocation style preset.
    @Published public var styleDisplayName: String = ProvocationStylePreset.socratic.displayName

    /// Called when the user requests to close the panel.
    public var onCloseRequested: (() -> Void)?
    /// Called when the user requests a new result for the current selection.
    ///
    /// - Parameter regenerateFromResponseID: The ID of the response to regenerate from, or `nil`.
    public var onRegenerateRequested: ((_ regenerateFromResponseID: UUID?) async -> Void)?
    /// Called when the pin state changes so the host can persist it.
    ///
    /// - Parameter isPinned: The new pinned state.
    public var onPinStateChanged: ((_ isPinned: Bool) -> Void)?

    private let timing: any FloatingPanelTiming
    private let pasteboardWriter: (String) -> Void
    private var autoDismissTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?

    /// Seconds after which the panel auto-dismisses when not pinned.
    public var autoDismissSeconds: TimeInterval
    /// Whether the panel dismisses automatically when the user copies a result.
    public var dismissOnCopy: Bool

    /// Creates a `FloatingPanelViewModel` with the given initial configuration.
    ///
    /// - Parameters:
    ///   - isPinned: Whether the panel starts pinned.
    ///   - dismissOnCopy: Whether the panel dismisses when the user copies a result.
    ///   - autoDismissSeconds: Delay before auto-dismiss (minimum 1 second). Defaults to 6.
    ///   - timing: Sleep provider for auto-dismiss and feedback timers.
    ///   - pasteboardWriter: Closure that writes text to the pasteboard. Defaults to `NSPasteboard.general`.
    ///   - styleDisplayName: Initial display name for the style label.
    public init(
        isPinned: Bool,
        dismissOnCopy: Bool,
        autoDismissSeconds: TimeInterval = 6,
        timing: any FloatingPanelTiming = SystemFloatingPanelTiming(),
        pasteboardWriter: ((String) -> Void)? = nil,
        styleDisplayName: String = ProvocationStylePreset.socratic.displayName
    ) {
        self.isPinned = isPinned
        self.dismissOnCopy = dismissOnCopy
        self.autoDismissSeconds = max(1, autoDismissSeconds)
        self.timing = timing
        self.pasteboardWriter = pasteboardWriter ?? FloatingPanelViewModel.defaultPasteboardWriter
        self.styleDisplayName = styleDisplayName
    }

    deinit {
        autoDismissTask?.cancel()
        feedbackTask?.cancel()
    }

    /// Resets the panel to the idle state and cancels all transient timers.
    public func setIdle() {
        state = .idle
        isRegenerating = false
        copyFeedback = nil
        suggestedAction = nil
        cancelTransientTasks()
    }

    /// Transitions the panel to a loading state.
    ///
    /// - Parameter selectedTextPreview: Optional truncated preview of the selected text to show while loading.
    public func setLoading(selectedTextPreview: String? = nil) {
        state = .loading(selectedTextPreview: normalizedPreview(selectedTextPreview))
        isRegenerating = false
        copyFeedback = nil
        suggestedAction = nil
        cancelTransientTasks()
    }

    /// Transitions the panel to the success state and schedules auto-dismiss if unpinned.
    ///
    /// - Parameter response: The successful ``ProvocationResponse`` to display.
    public func setSuccess(_ response: ProvocationResponse) {
        state = .success(response: response)
        isRegenerating = false
        copyFeedback = nil
        suggestedAction = nil
        scheduleAutoDismissIfNeeded()
    }

    /// Transitions the panel to an error state using the error's localised user message.
    ///
    /// - Parameter error: The ``FreeThinkerError`` to display.
    public func setError(_ error: FreeThinkerError) {
        setErrorMessage(error.userMessage)
    }

    /// Transitions the panel to an error state using a pre-mapped ``ErrorPresentation``.
    ///
    /// Sets `suggestedAction` if the presentation includes a non-`.none` action.
    ///
    /// - Parameter presentation: The mapped error presentation to display.
    public func setErrorPresentation(_ presentation: ErrorPresentation) {
        state = .error(message: presentation.message)
        isRegenerating = false
        copyFeedback = nil
        suggestedAction = presentation.action == .none ? nil : presentation.action
        scheduleAutoDismissIfNeeded()
    }

    /// Transitions the panel to an error state with a raw message string.
    ///
    /// Clears any pending `suggestedAction` and schedules auto-dismiss.
    /// Prefer ``setError(_:)`` or ``setErrorPresentation(_:)`` when a typed
    /// error or suggested action is available.
    ///
    /// - Parameter message: The localised error message to display.
    public func setErrorMessage(_ message: String) {
        state = .error(message: message)
        isRegenerating = false
        copyFeedback = nil
        suggestedAction = nil
        scheduleAutoDismissIfNeeded()
    }

    /// Copies the current result's body and follow-up question to the pasteboard.
    ///
    /// Sets `copyFeedback` to `"Copied"` briefly, then clears it. If `dismissOnCopy`
    /// is `true` and the panel is unpinned, the panel is closed after copying.
    public func copyCurrentResult() {
        guard let copyText else {
            return
        }

        pasteboardWriter(copyText)
        copyFeedback = "Copied"
        scheduleFeedbackClear()

        if dismissOnCopy, !isPinned {
            closePanel()
        }
    }

    /// Alias for ``copyCurrentResult()``.
    public func copyFromResponseContent() {
        copyCurrentResult()
    }

    /// Requests a new provocation generation for the same selected text.
    ///
    /// No-ops if ``canRegenerate`` is `false`. Sets `isRegenerating` to `true` while
    /// the request is in flight and resets it when the response arrives.
    public func requestRegenerate() {
        guard canRegenerate else {
            return
        }

        let regenerateFromResponseID = currentResponse?.id
        isRegenerating = true
        copyFeedback = nil

        Task { [weak self] in
            guard let self else { return }
            await onRegenerateRequested?(regenerateFromResponseID)
            if case .loading = state {
                return
            }
            isRegenerating = false
        }
    }

    /// Cancels pending timers and notifies the host to close the panel.
    public func closePanel() {
        cancelTransientTasks()
        onCloseRequested?()
    }

    /// Toggles the pinned state of the panel.
    ///
    /// When pinning, any pending auto-dismiss timer is cancelled. When unpinning,
    /// an auto-dismiss timer is started if the current state warrants one.
    public func togglePin() {
        isPinned.toggle()
        onPinStateChanged?(isPinned)
        if isPinned {
            autoDismissTask?.cancel()
            autoDismissTask = nil
        } else {
            scheduleAutoDismissIfNeeded()
        }
    }

    /// `true` when the panel is in the success state and ``copyText`` is non-nil.
    public var canCopy: Bool {
        guard case .success = state else {
            return false
        }
        return copyText != nil
    }

    /// `true` when the panel is in a state from which regeneration is possible and not already regenerating.
    public var canRegenerate: Bool {
        switch state {
        case .idle:
            return false
        case .loading:
            return false
        case .success, .error:
            return !isRegenerating
        }
    }

    /// Always `true`; the panel can always be closed by the user.
    public var canClose: Bool {
        true
    }

    /// The response currently displayed in the success state, or `nil` otherwise.
    public var currentResponse: ProvocationResponse? {
        if case let .success(response) = state {
            return response
        }
        return nil
    }

    /// The plain-text string that would be written to the pasteboard on copy.
    ///
    /// Combines the response body with the optional follow-up question, separated
    /// by a blank line. Returns `nil` when the panel is not in the success state
    /// or the response has no content.
    public var copyText: String? {
        guard let content = currentResponse?.content else {
            return nil
        }

        let followUp = content.followUpQuestion.map { "\n\nFollow-up: \($0)" } ?? ""
        return "\(content.body)\(followUp)"
    }

    /// A human-readable string describing the `suggestedAction`, or `nil` if there is none.
    public var suggestedActionMessage: String? {
        guard let suggestedAction else {
            return nil
        }

        switch suggestedAction {
        case .retry:
            return "Suggested action: Retry."
        case .openAccessibilitySettings:
            return "Suggested action: Open Accessibility settings."
        case .openHotkeySettings:
            return "Suggested action: Open hotkey settings."
        case .openSettings:
            return "Suggested action: Open settings."
        case .none:
            return nil
        }
    }
}

private extension FloatingPanelViewModel {
    static func defaultPasteboardWriter(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func normalizedPreview(_ text: String?) -> String? {
        guard let text else {
            return nil
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return String(trimmed.prefix(120))
    }

    func cancelTransientTasks() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        feedbackTask?.cancel()
        feedbackTask = nil
    }

    func scheduleFeedbackClear() {
        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            guard let self else { return }
            try? await timing.sleep(nanoseconds: 1_250_000_000)
            guard !Task.isCancelled else { return }
            copyFeedback = nil
        }
    }

    func scheduleAutoDismissIfNeeded() {
        autoDismissTask?.cancel()
        guard !isPinned else {
            return
        }

        switch state {
        case .success, .error:
            let nanoseconds = UInt64(autoDismissSeconds * 1_000_000_000)
            autoDismissTask = Task { [weak self] in
                guard let self else { return }
                try? await timing.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else { return }
                closePanel()
            }
        default:
            break
        }
    }
}
