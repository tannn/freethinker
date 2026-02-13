import AppKit
import ApplicationServices
import Carbon.HIToolbox.Events
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
    private let clipboardFallbackProvider: (@Sendable () -> String?)?
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
