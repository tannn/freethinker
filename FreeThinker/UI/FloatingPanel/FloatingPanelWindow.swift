import AppKit

public final class FloatingPanelWindow: NSPanel {
    public init(contentRect: NSRect = NSRect(x: 0, y: 0, width: 420, height: 340)) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear

        if let contentView = self.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 16
            contentView.layer?.masksToBounds = true
        }

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        animationBehavior = .utilityWindow
        isMovableByWindowBackground = true
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true

        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        standardWindowButton(.closeButton)?.isHidden = true
    }

    public override var canBecomeKey: Bool {
        true
    }

    public override var canBecomeMain: Bool {
        false
    }
}
