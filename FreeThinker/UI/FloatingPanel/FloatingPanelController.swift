import AppKit
import SwiftUI

@MainActor
public final class FloatingPanelController: NSObject {
    public private(set) var panel: FloatingPanelWindow

    private let viewModel: FloatingPanelViewModel
    private let hostingController: NSHostingController<FloatingPanelView>

    public init(viewModel: FloatingPanelViewModel) {
        self.viewModel = viewModel
        self.panel = FloatingPanelWindow()
        self.hostingController = NSHostingController(rootView: FloatingPanelView(viewModel: viewModel))

        super.init()

        panel.contentViewController = hostingController
        panel.delegate = self
    }

    public func show() {
        if panel.isVisible {
            panel.orderFront(nil)
            return
        }

        positionPanel()
        panel.orderFront(nil)
    }

    public func hide() {
        guard panel.isVisible else {
            return
        }
        panel.orderOut(nil)
    }

    public func toggle() {
        panel.isVisible ? hide() : show()
    }

    public func cleanup() {
        hide()
        panel.delegate = nil
        panel.contentViewController = nil
    }
}

private extension FloatingPanelController {
    func positionPanel() {
        let size = panel.frame.size
        let margin: CGFloat = 16

        let screen = activeScreen() ?? NSScreen.main
        guard let screen else {
            panel.center()
            return
        }

        let visibleFrame = screen.visibleFrame
        let pointer = NSEvent.mouseLocation

        let x = min(
            max(pointer.x - (size.width / 2), visibleFrame.minX + margin),
            visibleFrame.maxX - size.width - margin
        )

        let y = min(
            max(pointer.y - size.height - 20, visibleFrame.minY + margin),
            visibleFrame.maxY - size.height - margin
        )

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func activeScreen() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) }
    }
}

extension FloatingPanelController: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        viewModel.setIdle()
    }
}
