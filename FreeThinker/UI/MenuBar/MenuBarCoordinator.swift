import AppKit
import Combine
import Foundation

@MainActor
public final class MenuBarCoordinator: NSObject {
    public var onOpenSettings: (() -> Void)?
    public var onCheckForUpdates: (() -> Void)?
    public var onQuit: (() -> Void)?

    public private(set) var statusItem: NSStatusItem?

    private let appState: AppState
    private let orchestrator: any ProvocationOrchestrating
    private let menuBuilder: MenuBarMenuBuilder
    private let launchAtLoginController: any LaunchAtLoginControlling

    private var cancellables: Set<AnyCancellable> = []

    public init(
        appState: AppState,
        orchestrator: any ProvocationOrchestrating,
        menuBuilder: MenuBarMenuBuilder = MenuBarMenuBuilder(),
        launchAtLoginController: any LaunchAtLoginControlling = LaunchAtLoginService()
    ) {
        self.appState = appState
        self.orchestrator = orchestrator
        self.menuBuilder = menuBuilder
        self.launchAtLoginController = launchAtLoginController
        super.init()

        bindState()
    }

    public func installStatusItemIfNeeded() {
        guard statusItem == nil else {
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "FreeThinker")
        item.menu = makeMenu()

        statusItem = item
        Logger.info("Installed menu bar status item", category: .menuBar)
    }

    public func uninstallStatusItem() {
        guard let statusItem else {
            return
        }

        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
        Logger.info("Removed menu bar status item", category: .menuBar)
    }

    public func perform(_ command: MenuBarCommand) {
        switch command {
        case .generate:
            Task {
                _ = await orchestrator.trigger(source: .menu, regenerateFromResponseID: nil)
            }

        case .openSettings:
            onOpenSettings?()

        case .toggleLaunchAtLogin:
            toggleLaunchAtLogin()

        case .checkForUpdates:
            onCheckForUpdates?()

        case .quit:
            if let onQuit {
                onQuit()
            } else {
                NSApp.terminate(nil)
            }
        }
    }

    public func currentMenuDescriptors() -> [MenuBarMenuItemDescriptor] {
        menuBuilder.makeDescriptors(state: menuState())
    }

    @objc
    public func handleMenuItemAction(_ sender: NSMenuItem) {
        guard
            let raw = sender.representedObject as? String,
            let command = MenuBarCommand(rawValue: raw)
        else {
            return
        }

        perform(command)
    }
}

private extension MenuBarCoordinator {
    func bindState() {
        appState.$isGenerating
            .combineLatest(appState.$settings)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.reloadMenu()
            }
            .store(in: &cancellables)
    }

    func menuState() -> MenuBarMenuState {
        MenuBarMenuState(
            isGenerating: appState.isGenerating,
            launchAtLoginEnabled: appState.settings.launchAtLogin
        )
    }

    func makeMenu() -> NSMenu {
        menuBuilder.makeMenu(
            state: menuState(),
            target: self,
            action: #selector(handleMenuItemAction(_:))
        )
    }

    func reloadMenu() {
        statusItem?.menu = makeMenu()
    }

    func toggleLaunchAtLogin() {
        let targetState = !appState.settings.launchAtLogin

        do {
            try launchAtLoginController.setEnabled(targetState)
            var settings = appState.settings
            settings.launchAtLogin = targetState
            appState.updateSettings(settings)
        } catch {
            Logger.warning("Launch at login update failed error=\(error.localizedDescription)", category: .menuBar)
            appState.presentErrorMessage("Could not update launch at login. Try again from Settings.")
        }
    }
}
