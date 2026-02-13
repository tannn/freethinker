import AppKit
import ApplicationServices
import Foundation

public protocol ClipboardFallbackCaptureProtocol {
    var isEnabled: Bool { get }
    func captureSelectedText() async throws -> String
}

public protocol ClipboardStoring {
    var changeCount: Int { get }
    func currentString() -> String?
    func snapshot() -> ClipboardSnapshot
    func restore(_ snapshot: ClipboardSnapshot)
}

public struct ClipboardSnapshot: Sendable {
    public let items: [ClipboardSnapshotItem]

    public init(items: [ClipboardSnapshotItem]) {
        self.items = items
    }
}

public struct ClipboardSnapshotItem: Sendable {
    public let payloadByType: [NSPasteboard.PasteboardType.RawValue: Data]

    public init(payloadByType: [NSPasteboard.PasteboardType.RawValue: Data]) {
        self.payloadByType = payloadByType
    }
}

public struct SystemClipboardStore: ClipboardStoring {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public var changeCount: Int {
        pasteboard.changeCount
    }

    public func currentString() -> String? {
        pasteboard.string(forType: .string)
    }

    public func snapshot() -> ClipboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            var payload: [NSPasteboard.PasteboardType.RawValue: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    payload[type.rawValue] = data
                }
            }
            return ClipboardSnapshotItem(payloadByType: payload)
        }
        return ClipboardSnapshot(items: items)
    }

    public func restore(_ snapshot: ClipboardSnapshot) {
        pasteboard.clearContents()

        guard !snapshot.items.isEmpty else {
            return
        }

        let restoredItems = snapshot.items.map { snapshotItem in
            let pasteboardItem = NSPasteboardItem()
            for (rawType, data) in snapshotItem.payloadByType {
                pasteboardItem.setData(data, forType: NSPasteboard.PasteboardType(rawValue: rawType))
            }
            return pasteboardItem
        }

        pasteboard.writeObjects(restoredItems)
    }
}

public protocol CopyShortcutPerforming {
    func performCopyShortcut() throws
}

public struct SystemCopyShortcutPerformer: CopyShortcutPerforming {
    public init() {}

    public func performCopyShortcut() throws {
        guard let eventSource = CGEventSource(stateID: .hidSystemState) else {
            throw FreeThinkerError.captureFailed(reason: "Unable to create keyboard event source.")
        }

        let keyCodeForC: CGKeyCode = 8

        guard let keyDown = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCodeForC, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCodeForC, keyDown: false) else {
            throw FreeThinkerError.captureFailed(reason: "Unable to create copy keyboard events.")
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

public protocol SleepProviding {
    func sleep(for interval: TimeInterval) async throws
}

public struct TaskSleeper: SleepProviding {
    public init() {}

    public func sleep(for interval: TimeInterval) async throws {
        let nanoseconds = UInt64((interval * 1_000_000_000).rounded())
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

public final class ClipboardFallbackCapture: ClipboardFallbackCaptureProtocol {
    public let isEnabled: Bool

    private let clipboardStore: ClipboardStoring
    private let copyShortcutPerformer: CopyShortcutPerforming
    private let dateProvider: DateProviding
    private let sleeper: SleepProviding
    private let timeout: TimeInterval
    private let pollInterval: TimeInterval

    public init(
        isEnabled: Bool,
        clipboardStore: ClipboardStoring = SystemClipboardStore(),
        copyShortcutPerformer: CopyShortcutPerforming = SystemCopyShortcutPerformer(),
        dateProvider: DateProviding = SystemDateProvider(),
        sleeper: SleepProviding = TaskSleeper(),
        timeout: TimeInterval = 0.8,
        pollInterval: TimeInterval = 0.04
    ) {
        self.isEnabled = isEnabled
        self.clipboardStore = clipboardStore
        self.copyShortcutPerformer = copyShortcutPerformer
        self.dateProvider = dateProvider
        self.sleeper = sleeper
        self.timeout = timeout
        self.pollInterval = pollInterval
    }

    public func captureSelectedText() async throws -> String {
        guard isEnabled else {
            throw FreeThinkerError.fallbackDisabled
        }

        let snapshot = clipboardStore.snapshot()
        let initialChangeCount = clipboardStore.changeCount

        defer {
            clipboardStore.restore(snapshot)
        }

        try copyShortcutPerformer.performCopyShortcut()

        let deadline = dateProvider.now.addingTimeInterval(timeout)

        while dateProvider.now <= deadline {
            try Task.checkCancellation()

            if clipboardStore.changeCount > initialChangeCount,
               let copiedText = clipboardStore.currentString() {
                let normalized = Self.normalize(copiedText)
                guard !normalized.isEmpty else {
                    throw FreeThinkerError.noSelection
                }
                return normalized
            }

            try await sleeper.sleep(for: pollInterval)
        }

        throw FreeThinkerError.clipboardCaptureTimedOut
    }

    private static func normalize(_ rawText: String) -> String {
        rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
