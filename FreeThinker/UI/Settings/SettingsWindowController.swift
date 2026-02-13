import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public var onCheckForUpdates: (() -> Void)?

    public private(set) var window: NSWindow?

    private let appState: AppState
    private let navigationState: SettingsNavigationState

    public convenience init(appState: AppState) {
        self.init(
            appState: appState,
            navigationState: SettingsNavigationState()
        )
    }

    public init(
        appState: AppState,
        navigationState: SettingsNavigationState
    ) {
        self.appState = appState
        self.navigationState = navigationState
        super.init()
    }

    public func show(section: SettingsSection = .general) {
        navigationState.selectedSection = section

        if window == nil {
            window = makeWindow()
        }

        guard let window else {
            return
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    public func hide() {
        window?.orderOut(nil)
    }

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        true
    }
}

private extension SettingsWindowController {
    func makeWindow() -> NSWindow {
        let root = SettingsRootView(
            appState: appState,
            navigationState: navigationState,
            onCheckForUpdates: { [weak self] in
                self?.onCheckForUpdates?()
            }
        )
        let hostingController = NSHostingController(rootView: root)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 520),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "FreeThinker Settings"
        window.center()
        window.setFrameAutosaveName("FreeThinker.SettingsWindow")
        window.isReleasedWhenClosed = false
        window.level = .normal
        window.contentViewController = hostingController
        window.delegate = self

        return window
    }
}
