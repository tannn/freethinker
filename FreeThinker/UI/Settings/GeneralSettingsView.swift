import SwiftUI

public struct GeneralSettingsView: View {
    @ObservedObject private var appState: AppState
    @ObservedObject private var panelViewModel: FloatingPanelViewModel

    private let onCheckForUpdates: (() -> Void)?

    @State private var exportStatus: String?

    public init(
        appState: AppState,
        onCheckForUpdates: (() -> Void)? = nil
    ) {
        self.appState = appState
        _panelViewModel = ObservedObject(wrappedValue: appState.panelViewModel)
        self.onCheckForUpdates = onCheckForUpdates
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("General")
                    .font(.title2.weight(.semibold))

                feedbackView

                behaviorSection
                launchSection
                updatesSection
                diagnosticsSection
                onboardingSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onDisappear {
            appState.clearSettingsFeedback()
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

    var updatesSection: some View {
        GroupBox("Updates") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Automatically check for updates", isOn: automaticallyCheckForUpdatesBinding)
                    .accessibilityIdentifier(SettingsAccessibility.Identifier.generalAutoUpdateToggle)

                Picker("Update channel", selection: appUpdateChannelBinding) {
                    ForEach(AppUpdateChannel.allCases) { channel in
                        Text(channel.displayName)
                            .tag(channel)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(SettingsAccessibility.Identifier.generalUpdateChannelPicker)

                Button("Check for Updates Now") {
                    onCheckForUpdates?()
                }
                .accessibilityIdentifier(SettingsAccessibility.Identifier.generalCheckForUpdatesButton)

                Text("Updates are delivered via direct download in this build.")
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

    var automaticallyCheckForUpdatesBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.automaticallyCheckForUpdates },
            set: { isEnabled in
                Task { await appState.setAutomaticallyCheckForUpdates(isEnabled) }
            }
        )
    }

    var appUpdateChannelBinding: Binding<AppUpdateChannel> {
        Binding(
            get: { appState.settings.appUpdateChannel },
            set: { channel in
                Task { await appState.setAppUpdateChannel(channel) }
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
}
