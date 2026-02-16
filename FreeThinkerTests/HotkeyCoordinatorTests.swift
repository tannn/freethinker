import AppKit
import KeyboardShortcuts
import XCTest
@testable import FreeThinker

@MainActor
final class HotkeyCoordinatorTests: XCTestCase {
    private var originalShortcut: KeyboardShortcuts.Shortcut?

    override func setUp() {
        super.setUp()
        originalShortcut = KeyboardShortcuts.Name.popup.shortcut
        HotkeyCoordinator.shared.stopListening()
    }

    override func tearDown() {
        KeyboardShortcuts.Name.popup.shortcut = originalShortcut
        HotkeyCoordinator.shared.stopListening()
        super.tearDown()
    }

    func testRefreshSyncsPersistedShortcutWhenHotkeyEnabled() {
        let persisted = HotkeyShortcut(
            modifiers: Int(NSEvent.ModifierFlags.command.union(.option).rawValue),
            keyCode: 46
        )
        let expected = KeyboardShortcuts.Shortcut(
            KeyboardShortcuts.Key(rawValue: persisted.keyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(persisted.modifiers))
        )
        KeyboardShortcuts.Name.popup.shortcut = KeyboardShortcuts.Shortcut(.p, modifiers: [.command, .shift])

        HotkeyCoordinator.shared.refresh(using: AppSettings(
            hotkeyEnabled: true,
            hotkeyModifiers: persisted.modifiers,
            hotkeyKeyCode: persisted.keyCode
        ))

        XCTAssertEqual(KeyboardShortcuts.Name.popup.shortcut, expected)
    }

    func testRefreshSyncsPersistedShortcutWhenHotkeyDisabled() {
        let persisted = HotkeyShortcut(
            modifiers: Int(NSEvent.ModifierFlags.command.union(.control).rawValue),
            keyCode: 17
        )
        let expected = KeyboardShortcuts.Shortcut(
            KeyboardShortcuts.Key(rawValue: persisted.keyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(persisted.modifiers))
        )
        KeyboardShortcuts.Name.popup.shortcut = KeyboardShortcuts.Shortcut(.p, modifiers: [.command, .shift])

        HotkeyCoordinator.shared.refresh(using: AppSettings(
            hotkeyEnabled: false,
            hotkeyModifiers: persisted.modifiers,
            hotkeyKeyCode: persisted.keyCode
        ))

        XCTAssertEqual(KeyboardShortcuts.Name.popup.shortcut, expected)
    }
}
