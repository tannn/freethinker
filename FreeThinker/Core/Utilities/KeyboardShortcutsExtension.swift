import AppKit
import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let popup = Self("popup", default: .init(.p, modifiers: [.command, .shift]))
}

@MainActor
public final class HotkeyCoordinator: ObservableObject {
    public static let shared = HotkeyCoordinator()

    public var onTrigger: (() -> Void)?

    private var isListening = false

    private init() {}

    public func startListening() {
        guard !isListening else { return }
        isListening = true

        KeyboardShortcuts.onKeyUp(for: .popup) { [weak self] in
            Task { @MainActor in
                self?.onTrigger?()
            }
        }
    }

    public func stopListening() {
        KeyboardShortcuts.disable(.popup)
        isListening = false
    }

    public func refresh(using settings: AppSettings) {
        let shortcut = KeyboardShortcuts.Shortcut(
            KeyboardShortcuts.Key(rawValue: settings.hotkeyShortcut.keyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.hotkeyShortcut.modifiers))
        )
        if KeyboardShortcuts.Name.popup.shortcut != shortcut {
            KeyboardShortcuts.Name.popup.shortcut = shortcut
        }

        if settings.hotkeyEnabled {
            KeyboardShortcuts.enable(.popup)
            startListening()
        } else {
            stopListening()
        }
    }
}
