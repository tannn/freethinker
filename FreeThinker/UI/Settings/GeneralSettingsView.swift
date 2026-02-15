import AppKit
import SwiftUI

public struct GeneralSettingsView: View {
    @ObservedObject private var appState: AppState
    @ObservedObject private var panelViewModel: FloatingPanelViewModel

    @State private var exportStatus: String?
    @State private var draftHotkeyModifiers: Int
    @State private var draftHotkeyKeyCode: Int

    public init(appState: AppState) {
        self.appState = appState
        _panelViewModel = ObservedObject(wrappedValue: appState.panelViewModel)
        _draftHotkeyModifiers = State(initialValue: appState.settings.hotkeyShortcut.modifiers)
        _draftHotkeyKeyCode = State(initialValue: appState.settings.hotkeyShortcut.keyCode)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("General")
                    .font(.title2.weight(.semibold))

                feedbackView

                behaviorSection
                hotkeyShortcutSection
                launchSection
                diagnosticsSection
                onboardingSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onDisappear {
            appState.clearSettingsFeedback()
        }
        .onChange(of: appState.settings.hotkeyShortcut) { _, shortcut in
            draftHotkeyModifiers = shortcut.modifiers
            draftHotkeyKeyCode = shortcut.keyCode
        }
    }
}

private extension GeneralSettingsView {
    @ViewBuilder
    var feedbackView: some View {
        if let settingsValidationMessage = appState.settingsValidationMessage {
            Label(settingsValidationMessage, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.callout)
                .accessibilityIdentifier(SettingsAccessibility.Identifier.feedbackValidation)
        }

        if let settingsSaveErrorMessage = appState.settingsSaveErrorMessage {
            Label(settingsSaveErrorMessage, systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
                .font(.callout)
                .accessibilityIdentifier(SettingsAccessibility.Identifier.feedbackSaveError)
        }

        if appState.isPersistingSettings {
            ProgressView("Saving…")
                .controlSize(.small)
                .accessibilityIdentifier(SettingsAccessibility.Identifier.feedbackSaving)
        }
    }

    var behaviorSection: some View {
        GroupBox("Behavior") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable global hotkey (Cmd+Shift+P)", isOn: hotkeyEnabledBinding)
                    .disabled(hotkeyToggleLocked)
                    .accessibilityIdentifier(SettingsAccessibility.Identifier.generalHotkeyToggle)

                Toggle("Show menu bar icon", isOn: showMenuBarIconBinding)
                    .disabled(menuBarIconToggleLocked)
                    .accessibilityIdentifier(SettingsAccessibility.Identifier.generalMenuBarToggle)

                Toggle("Dismiss panel after copying", isOn: dismissOnCopyBinding)
                    .accessibilityIdentifier(SettingsAccessibility.Identifier.generalDismissOnCopyToggle)

                Stepper(
                    value: autoDismissSecondsBinding,
                    in: AppSettings.minAutoDismissSeconds...AppSettings.maxAutoDismissSeconds,
                    step: 1
                ) {
                    Text("Auto-dismiss panel after \(Int(appState.settings.autoDismissSeconds)) seconds")
                }
                .accessibilityIdentifier(SettingsAccessibility.Identifier.generalAutoDismissStepper)

                Toggle("Enable fallback text capture", isOn: fallbackCaptureBinding)
                    .accessibilityIdentifier(SettingsAccessibility.Identifier.generalFallbackCaptureToggle)

                Toggle("Keep panel pinned between triggers", isOn: panelPinnedBinding)
                    .accessibilityIdentifier(SettingsAccessibility.Identifier.generalPinPanelToggle)

                Text("Keep either Hotkey or Menu Bar Icon enabled so FreeThinker always remains reachable.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if hotkeyToggleLocked || menuBarIconToggleLocked {
                    Text("To turn one off, first enable the other.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var launchSection: some View {
        GroupBox("Startup") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                    .accessibilityIdentifier(SettingsAccessibility.Identifier.generalLaunchAtLoginToggle)

                Text("Launch at Login controls whether FreeThinker starts automatically when you sign in.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var hotkeyShortcutSection: some View {
        GroupBox("Hotkey Shortcut") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Current shortcut: \(appState.settings.hotkeyShortcut.displayString)")
                    .font(.callout.weight(.medium))

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Modifiers")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Toggle("Cmd", isOn: modifierBinding(.command))
                            Toggle("Shift", isOn: modifierBinding(.shift))
                            Toggle("Option", isOn: modifierBinding(.option))
                            Toggle("Ctrl", isOn: modifierBinding(.control))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("Key", selection: $draftHotkeyKeyCode) {
                            ForEach(Self.hotkeyKeyOptions, id: \.keyCode) { option in
                                Text(option.label)
                                    .tag(option.keyCode)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: 150, alignment: .leading)
                        .accessibilityIdentifier(SettingsAccessibility.Identifier.generalHotkeyEditor)
                    }
                }

                HStack(spacing: 10) {
                    Button("Apply Shortcut") {
                        let proposed = HotkeyShortcut(
                            modifiers: draftHotkeyModifiers,
                            keyCode: draftHotkeyKeyCode
                        )
                        _ = appState.applyHotkeyShortcut(proposed)
                    }
                    .disabled(appState.settings.hotkeyEnabled == false)

                    Button("Reset to Default") {
                        _ = appState.resetHotkeyShortcutToDefault()
                    }
                    .disabled(appState.settings.hotkeyEnabled == false)
                    .accessibilityIdentifier(SettingsAccessibility.Identifier.generalHotkeyResetButton)
                }

                if let result = appState.hotkeyCustomizationResult,
                   let message = result.message {
                    Label(message, systemImage: result.isAccepted ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(result.isAccepted ? .green : .red)
                        .font(.footnote)
                        .accessibilityIdentifier(SettingsAccessibility.Identifier.generalHotkeyFeedback)
                }

                Text("Include at least one modifier key. Some macOS shortcuts are reserved and cannot be used.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    var diagnosticsSection: some View {
        GroupBox("Diagnostics") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable local diagnostics logging", isOn: diagnosticsEnabledBinding)

                Text("Diagnostics never store raw selected text or prompts. Sensitive keys are redacted.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Button("Export Diagnostics Log…") {
                        exportStatus = appState.onExportDiagnosticsRequested?() ?? "Export unavailable"
                    }
                    .disabled(appState.settings.diagnosticsEnabled == false)

                    if let exportStatus {
                        Text(exportStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var onboardingSection: some View {
        GroupBox("Onboarding") {
            VStack(alignment: .leading, spacing: 10) {
                Button("Reopen Onboarding Guide") {
                    appState.presentOnboarding()
                }

                if appState.settings.onboardingCompleted {
                    Text("Checklist complete")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension GeneralSettingsView {
    static let hotkeyModifierMask: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
    static let hotkeyKeyOptions: [(keyCode: Int, label: String)] = [
        (0, "A"),
        (11, "B"),
        (8, "C"),
        (2, "D"),
        (14, "E"),
        (3, "F"),
        (5, "G"),
        (4, "H"),
        (34, "I"),
        (38, "J"),
        (40, "K"),
        (37, "L"),
        (46, "M"),
        (45, "N"),
        (31, "O"),
        (35, "P"),
        (12, "Q"),
        (15, "R"),
        (1, "S"),
        (17, "T"),
        (32, "U"),
        (9, "V"),
        (13, "W"),
        (7, "X"),
        (16, "Y"),
        (6, "Z"),
        (29, "0"),
        (18, "1"),
        (19, "2"),
        (20, "3"),
        (21, "4"),
        (23, "5"),
        (22, "6"),
        (26, "7"),
        (28, "8"),
        (25, "9"),
        (49, "Space")
    ]

    var hotkeyEnabledBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.hotkeyEnabled },
            set: { isEnabled in
                Task { await appState.setHotkeyEnabled(isEnabled) }
            }
        )
    }

    var showMenuBarIconBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.showMenuBarIcon },
            set: { isEnabled in
                Task { await appState.setShowMenuBarIcon(isEnabled) }
            }
        )
    }

    var dismissOnCopyBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.dismissOnCopy },
            set: { isEnabled in
                Task { await appState.setDismissOnCopy(isEnabled) }
            }
        )
    }

    var autoDismissSecondsBinding: Binding<TimeInterval> {
        Binding(
            get: { appState.settings.autoDismissSeconds },
            set: { seconds in
                Task { await appState.setAutoDismissSeconds(seconds) }
            }
        )
    }

    var fallbackCaptureBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.fallbackCaptureEnabled },
            set: { isEnabled in
                Task { await appState.setFallbackCaptureEnabled(isEnabled) }
            }
        )
    }

    var panelPinnedBinding: Binding<Bool> {
        Binding(
            get: { panelViewModel.isPinned },
            set: { isPinned in
                Task { await appState.setPanelPinned(isPinned) }
            }
        )
    }

    var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.launchAtLogin },
            set: { isEnabled in
                Task { await appState.setLaunchAtLoginEnabled(isEnabled) }
            }
        )
    }

    var diagnosticsEnabledBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.diagnosticsEnabled },
            set: { value in
                var settings = appState.settings
                settings.diagnosticsEnabled = value
                appState.updateSettings(settings)
            }
        )
    }

    var hotkeyToggleLocked: Bool {
        appState.settings.hotkeyEnabled && !appState.settings.showMenuBarIcon
    }

    var menuBarIconToggleLocked: Bool {
        !appState.settings.hotkeyEnabled && appState.settings.showMenuBarIcon
    }

    func modifierBinding(_ modifier: NSEvent.ModifierFlags) -> Binding<Bool> {
        Binding(
            get: {
                hotkeyModifierFlags.contains(modifier)
            },
            set: { isEnabled in
                var updated = hotkeyModifierFlags
                if isEnabled {
                    updated.insert(modifier)
                } else {
                    updated.remove(modifier)
                }

                draftHotkeyModifiers = Int(updated.intersection(Self.hotkeyModifierMask).rawValue)
            }
        )
    }

    var hotkeyModifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: UInt(draftHotkeyModifiers)).intersection(Self.hotkeyModifierMask)
    }
}

