import AppKit
import Combine
import Foundation

public protocol FloatingPanelTiming: Sendable {
    func sleep(nanoseconds: UInt64) async throws
}

public struct SystemFloatingPanelTiming: FloatingPanelTiming {
    public init() {}

    public func sleep(nanoseconds: UInt64) async throws {
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

@MainActor
public final class FloatingPanelViewModel: ObservableObject {
    public enum State: Equatable {
        case idle
        case loading(selectedTextPreview: String?)
        case success(response: ProvocationResponse)
        case error(message: String)
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var isPinned: Bool
    @Published public private(set) var isRegenerating: Bool = false
    @Published public private(set) var copyFeedback: String?

    public var onCloseRequested: (() -> Void)?
    public var onRegenerateRequested: ((_ regenerateFromResponseID: UUID?) async -> Void)?
    public var onPinStateChanged: ((_ isPinned: Bool) -> Void)?

    private let timing: any FloatingPanelTiming
    private let pasteboardWriter: (String) -> Void
    private var autoDismissTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?

    public var autoDismissSeconds: TimeInterval
    public var dismissOnCopy: Bool

    public init(
        isPinned: Bool,
        dismissOnCopy: Bool,
        autoDismissSeconds: TimeInterval = 6,
        timing: any FloatingPanelTiming = SystemFloatingPanelTiming(),
        pasteboardWriter: ((String) -> Void)? = nil
    ) {
        self.isPinned = isPinned
        self.dismissOnCopy = dismissOnCopy
        self.autoDismissSeconds = max(1, autoDismissSeconds)
        self.timing = timing
        self.pasteboardWriter = pasteboardWriter ?? FloatingPanelViewModel.defaultPasteboardWriter
    }

    deinit {
        autoDismissTask?.cancel()
        feedbackTask?.cancel()
    }

    public func setIdle() {
        state = .idle
        isRegenerating = false
        copyFeedback = nil
        cancelTransientTasks()
    }

    public func setLoading(selectedTextPreview: String? = nil) {
        state = .loading(selectedTextPreview: normalizedPreview(selectedTextPreview))
        isRegenerating = false
        copyFeedback = nil
        cancelTransientTasks()
    }

    public func setSuccess(_ response: ProvocationResponse) {
        state = .success(response: response)
        isRegenerating = false
        copyFeedback = nil
        scheduleAutoDismissIfNeeded()
    }

    public func setError(_ error: FreeThinkerError) {
        setErrorMessage(error.userMessage)
    }

    public func setErrorMessage(_ message: String) {
        state = .error(message: message)
        isRegenerating = false
        copyFeedback = nil
        scheduleAutoDismissIfNeeded()
    }

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

    public func closePanel() {
        cancelTransientTasks()
        onCloseRequested?()
    }

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

    public var canCopy: Bool {
        guard case .success = state else {
            return false
        }
        return copyText != nil
    }

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

    public var canClose: Bool {
        true
    }

    public var currentResponse: ProvocationResponse? {
        if case let .success(response) = state {
            return response
        }
        return nil
    }

    public var copyText: String? {
        guard let content = currentResponse?.content else {
            return nil
        }

        let followUp = content.followUpQuestion.map { "\n\nFollow-up: \($0)" } ?? ""
        return "\(content.headline)\n\n\(content.body)\(followUp)"
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
