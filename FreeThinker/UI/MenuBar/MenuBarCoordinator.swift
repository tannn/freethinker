import AppKit

@MainActor
final class MenuBarCoordinator: NSObject {
    private let container: AppContainer
    private var statusItem: NSStatusItem?
    private lazy var menu: NSMenu = makeMenu()

    init(container: AppContainer) {
        self.container = container
    }

    func start() {
        guard statusItem == nil else {
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "bolt.horizontal.circle",
            accessibilityDescription: "FreeThinker"
        )
        item.button?.toolTip = "FreeThinker"
        item.menu = menu

        statusItem = item
        AppLog.menuBar.info("Menu bar coordinator started.")
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "FreeThinker")

        let generateItem = NSMenuItem(
            title: "Generate Provocation",
            action: #selector(handleGenerateProvocation),
            keyEquivalent: "p"
        )
        generateItem.keyEquivalentModifierMask = [.command, .shift]
        generateItem.target = self

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self

        let quitItem = NSMenuItem(
            title: "Quit FreeThinker",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self

        menu.addItem(generateItem)
        menu.addItem(.separator())
        menu.addItem(settingsItem)
        menu.addItem(quitItem)

        return menu
    }

    @objc
    private func handleGenerateProvocation() {
        AppLog.menuBar.notice("Generate provocation action selected.")

        Task {
            let capturedTextResult = await container.textCaptureService.captureSelectedText()

            switch capturedTextResult {
            case let .success(capturedText):
                let request = ProvocationRequest(
                    selectedText: capturedText.text,
                    sourceApplication: capturedText.sourceApplication
                )
                _ = await container.aiService.generateProvocation(for: request)
            case let .failure(error):
                AppLog.services.error("Unable to capture text: \(error.localizedDescription)")
            }
        }
    }

    @objc
    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }
}
