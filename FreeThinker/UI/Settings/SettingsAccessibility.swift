import Foundation

public enum SettingsAccessibility {
    public enum Identifier {
        public static let root = "settings.root"
        public static let sidebar = "settings.sidebar"
        public static let sectionGeneral = "settings.section.general"
        public static let sectionProvocation = "settings.section.provocation"
        public static let sectionAccessibility = "settings.section.accessibility"

        public static let feedbackValidation = "settings.feedback.validation"
        public static let feedbackSaveError = "settings.feedback.save_error"
        public static let feedbackSaving = "settings.feedback.saving"

        public static let generalHotkeyToggle = "settings.general.hotkey_enabled"
        public static let generalMenuBarToggle = "settings.general.menu_bar_icon"
        public static let generalDismissOnCopyToggle = "settings.general.dismiss_on_copy"
        public static let generalAutoDismissStepper = "settings.general.auto_dismiss_seconds"
        public static let generalFallbackCaptureToggle = "settings.general.fallback_capture"
        public static let generalPinPanelToggle = "settings.general.pin_panel"
        public static let generalLaunchAtLoginToggle = "settings.general.launch_at_login"
        public static let generalAutoUpdateToggle = "settings.general.auto_update"
        public static let generalUpdateChannelPicker = "settings.general.update_channel"
        public static let generalCheckForUpdatesButton = "settings.general.check_for_updates"

        public static let provocationPresetPicker = "settings.provocation.style_preset"
        public static let provocationCustomInstructionEditor = "settings.provocation.custom_instruction"
        public static let provocationCharacterCount = "settings.provocation.character_count"
        public static let provocationResetButton = "settings.provocation.reset"
    }
}
