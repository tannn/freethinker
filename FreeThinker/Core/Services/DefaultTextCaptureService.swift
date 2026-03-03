import AppKit
import ApplicationServices
import Carbon.HIToolbox.Events
import Foundation

/// The result of checking whether the app has Accessibility permission.
public enum TextCapturePermissionStatus: Equatable, Sendable {
    /// Permission has been granted; text capture can proceed.
    case granted
    /// Permission has been denied; capture will fail.
    case denied
}

/// Protocol for reading the user's currently selected text from the active application.
///
/// Conforming types are actors to ensure safe concurrent access to their mutable state.
public protocol TextCaptureServiceProtocol: Actor, Sendable {
    /// Checks whether Accessibility permission is available without prompting.
    ///
    /// - Returns: ``TextCapturePermissionStatus/granted`` if the app can read selected text.
    func preflightPermission() -> TextCapturePermissionStatus

    /// Enables or disables the clipboard-based fallback capture strategy.
    ///
    /// - Parameter isEnabled: `true` to allow clipboard fallback; `false` to disable it.
    func setFallbackCaptureEnabled(_ isEnabled: Bool)

    /// Reads the user's currently selected text from the focused application.
    ///
    /// Tries the Accessibility API first. If that yields no text and fallback is enabled,
    /// it simulates Cmd+C and reads the clipboard result, restoring the original clipboard
    /// contents afterwards.
    ///
    /// - Returns: The trimmed selected text, truncated to ``ProvocationRequest/maxSelectedTextLength``.
    /// - Throws: ``FreeThinkerError/accessibilityPermissionDenied`` if permission is absent,
    ///   or ``FreeThinkerError/noSelection`` if no text could be captured.
    func captureSelectedText() async throws -> String

    /// Presents the macOS Accessibility permission prompt if one has not been shown recently.
    ///
    /// Respects a cooldown window to avoid showing the prompt repeatedly.
    func requestAccessibilityPermissionPromptIfNeeded()
}

/// Concrete actor that implements ``TextCaptureServiceProtocol`` using the Accessibility API
/// with an optional clipboard-based fallback.
///
/// All dependencies are injectable for unit testing, including the permission checker,
/// the AX selection provider, and the clipboard fallback provider.
public actor DefaultTextCaptureService: TextCaptureServiceProtocol {
    private let maxSelectionLength: Int
    private let permissionChecker: @Sendable () -> Bool
    private let permissionPromptRequester: @Sendable () -> Bool
    private let permissionPromptCooldownNanoseconds: UInt64
    private let uptimeNanosecondsProvider: @Sendable () -> UInt64
    private let accessibilityReachabilityProbe: @Sendable () -> Bool
    private let accessibilitySelectionProvider: @Sendable () -> String?
    private let clipboardFallbackProvider: (@Sendable () -> String?)?
    private var fallbackCaptureEnabled: Bool
    private var lastPermissionPromptUptimeNanoseconds: UInt64?

    /// Creates a `DefaultTextCaptureService` with injectable dependencies.
    ///
    /// - Parameters:
    ///   - maxSelectionLength: Characters to retain from the captured selection.
    ///     Defaults to ``ProvocationRequest/maxSelectedTextLength``.
    ///   - fallbackCaptureEnabled: Whether the clipboard fallback strategy is active. Defaults to `true`.
    ///   - permissionChecker: Closure that returns `AXIsProcessTrusted()`. Injected for testing.
    ///   - permissionPromptRequester: Closure that requests the Accessibility prompt. Injected for testing.
    ///   - permissionPromptCooldownNanoseconds: Minimum nanoseconds between successive prompts.
    ///     Defaults to 6 seconds.
    ///   - uptimeNanosecondsProvider: Closure returning the current system uptime. Injected for testing.
    ///   - accessibilityReachabilityProbe: Probe that verifies the AX API is reachable. Injected for testing.
    ///   - accessibilitySelectionProvider: Closure reading `kAXSelectedTextAttribute`. Injected for testing.
    ///   - clipboardFallbackProvider: Optional replacement for the Cmd+C fallback. Injected for testing.
    public init(
        maxSelectionLength: Int = ProvocationRequest.maxSelectedTextLength,
        fallbackCaptureEnabled: Bool = true,
        permissionChecker: (@Sendable () -> Bool)? = nil,
        permissionPromptRequester: (@Sendable () -> Bool)? = nil,
        permissionPromptCooldownNanoseconds: UInt64 = 6_000_000_000,
        uptimeNanosecondsProvider: (@Sendable () -> UInt64)? = nil,
        accessibilityReachabilityProbe: (@Sendable () -> Bool)? = nil,
        accessibilitySelectionProvider: (@Sendable () -> String?)? = nil,
        clipboardFallbackProvider: (@Sendable () -> String?)? = nil
    ) {
        self.maxSelectionLength = maxSelectionLength
        self.fallbackCaptureEnabled = fallbackCaptureEnabled
        self.permissionChecker = permissionChecker ?? { AXIsProcessTrusted() }
        self.permissionPromptRequester = permissionPromptRequester ?? {
            Self.requestAccessibilityPermissionPrompt()
        }
        self.permissionPromptCooldownNanoseconds = permissionPromptCooldownNanoseconds
        self.uptimeNanosecondsProvider = uptimeNanosecondsProvider ?? {
            DispatchTime.now().uptimeNanoseconds
        }
        self.accessibilityReachabilityProbe = accessibilityReachabilityProbe ?? {
            Self.isAccessibilityAPIReachable()
        }
        self.accessibilitySelectionProvider = accessibilitySelectionProvider ?? {
            Self.captureAccessibilitySelectedText()
        }
        self.clipboardFallbackProvider = clipboardFallbackProvider
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
            requestAccessibilityPermissionPromptIfNeeded()
            Logger.warning("Selection capture blocked: accessibility permission denied", category: .textCapture)
            throw FreeThinkerError.accessibilityPermissionDenied
        }

        if let captured = normalizedSelection(from: accessibilitySelectionProvider()) {
            Logger.debug("Selection captured via accessibility characters=\(captured.count)", category: .textCapture)
            return String(captured.prefix(maxSelectionLength))
        }

        if fallbackCaptureEnabled, let captured = normalizedSelection(from: await fallbackCaptureSelection()) {
            Logger.info("Selection captured via clipboard fallback", category: .textCapture)
            return String(captured.prefix(maxSelectionLength))
        }

        try Task.checkCancellation()

        Logger.info("Selection capture yielded no text", category: .textCapture)
        throw FreeThinkerError.noSelection
    }

    public func requestAccessibilityPermissionPromptIfNeeded() {
        let now = uptimeNanosecondsProvider()
        if
            let lastPromptUptime = lastPermissionPromptUptimeNanoseconds,
            now >= lastPromptUptime,
            (now - lastPromptUptime) < permissionPromptCooldownNanoseconds
        {
            return
        }

        lastPermissionPromptUptimeNanoseconds = now
        let alreadyTrusted = permissionPromptRequester()
        Logger.info(
            "Requested accessibility permission prompt trusted=\(alreadyTrusted)",
            category: .textCapture
        )
    }
}

private extension DefaultTextCaptureService {
    struct PasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]]
    }

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

    @discardableResult
    static func requestAccessibilityPermissionPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func fallbackCaptureSelection() async -> String? {
        if let clipboardFallbackProvider {
            return clipboardFallbackProvider()
        }

        return await Self.captureViaClipboardCopyAndRestore()
    }

    static func captureViaClipboardCopyAndRestore() async -> String? {
        let pasteboard = NSPasteboard.general
        let snapshot = capturePasteboardSnapshot(from: pasteboard)
        let baselineChangeCount = pasteboard.changeCount

        triggerCopyShortcut()

        let attempts = 6
        for _ in 0..<attempts where pasteboard.changeCount == baselineChangeCount {
            try? await Task.sleep(nanoseconds: 40_000_000)
        }

        let captured = pasteboard.changeCount == baselineChangeCount
            ? nil
            : pasteboard.string(forType: .string)

        restorePasteboard(snapshot, to: pasteboard)
        return captured
    }

    static func capturePasteboardSnapshot(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let itemPayloads = (pasteboard.pasteboardItems ?? []).map { item in
            var payload: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    payload[type] = data
                }
            }
            return payload
        }

        return PasteboardSnapshot(items: itemPayloads)
    }

    static func restorePasteboard(_ snapshot: PasteboardSnapshot, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else {
            return
        }

        let restoredItems = snapshot.items.map { payload -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in payload {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restoredItems)
    }

    static func triggerCopyShortcut() {
        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
