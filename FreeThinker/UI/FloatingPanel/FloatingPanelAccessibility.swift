import Foundation

public enum FloatingPanelAccessibility {
    public enum Identifier {
        public static let panel = "floating_panel.root"
        public static let loadingIndicator = "floating_panel.loading"
        public static let responseCard = "floating_panel.response"
        public static let errorCallout = "floating_panel.error"
        public static let copyButton = "floating_panel.action.copy"
        public static let regenerateButton = "floating_panel.action.regenerate"
        public static let closeButton = "floating_panel.action.close"
        public static let pinButton = "floating_panel.action.pin"
        public static let feedbackLabel = "floating_panel.feedback"
    }

    public enum Label {
        public static let panelTitle = "Provocation"
        public static let loading = "Generating provocation"
        public static let copy = "Copy provocation"
        public static let regenerate = "Regenerate provocation"
        public static let close = "Close panel"
        public static let pin = "Pin panel"
        public static let unpin = "Unpin panel"
        public static let error = "Generation error"
    }

    public enum Hint {
        public static let copy = "Copies the current provocation to the clipboard"
        public static let regenerate = "Requests a new provocation using the same input"
        public static let close = "Dismisses the floating panel"
        public static let pin = "Keeps the panel open across generation cycles"
        public static let unpin = "Allows the panel to auto-dismiss"
        public static let error = "Review the error details, then retry generation"
    }
}
