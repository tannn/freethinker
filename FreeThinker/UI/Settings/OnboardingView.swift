import AppKit
import SwiftUI

@MainActor
public struct OnboardingView: View {
    @ObservedObject private var appState: AppState

    private let openAccessibilitySettings: () -> Void
    private let openModelSettings: () -> Void
    private let refreshReadiness: () -> Void

    public init(
        appState: AppState,
        openAccessibilitySettings: @escaping () -> Void,
        openModelSettings: @escaping () -> Void,
        refreshReadiness: @escaping () -> Void
    ) {
        self.appState = appState
        self.openAccessibilitySettings = openAccessibilitySettings
        self.openModelSettings = openModelSettings
        self.refreshReadiness = refreshReadiness
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Welcome to FreeThinker")
                .font(.title2.bold())

            Text("Complete this quick readiness check. You can skip now and reopen it later from the menu.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                checklistRow(
                    title: "Accessibility Permission",
                    subtitle: appState.onboardingReadiness.accessibilityGranted
                        ? "Enabled"
                        : "Required to capture selected text from other apps.",
                    completed: appState.onboardingReadiness.accessibilityGranted,
                    buttonTitle: "Open Settings",
                    disableButtonWhenCompleted: true,
                    action: openAccessibilitySettings
                )

                checklistRow(
                    title: "Hotkey Awareness",
                    subtitle: appState.onboardingReadiness.hotkeyAwarenessConfirmed
                        ? "Cmd+Shift+P confirmed"
                        : "Use Cmd+Shift+P to generate provocations from selected text.",
                    completed: appState.onboardingReadiness.hotkeyAwarenessConfirmed,
                    buttonTitle: appState.onboardingReadiness.hotkeyAwarenessConfirmed ? "Confirmed" : "I Understand",
                    disableButtonWhenCompleted: true
                ) {
                    appState.setHotkeyAwarenessConfirmed(true)
                }

                checklistRow(
                    title: "On-Device AI Support",
                    subtitle: modelSupportSubtitle,
                    completed: appState.onboardingReadiness.isModelReady,
                    buttonTitle: "Open Settings",
                    disableButtonWhenCompleted: false,
                    action: openModelSettings
                )
            }

            HStack {
                Button("Refresh Status") {
                    refreshReadiness()
                }

                Spacer()

                Button("Skip for Now") {
                    appState.dismissOnboarding(markSeen: true)
                }

                Button("Finish") {
                    appState.completeOnboarding()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!appState.onboardingReadiness.isChecklistComplete)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(width: 560)
    }

    private var modelSupportSubtitle: String {
        switch appState.onboardingReadiness.modelAvailability {
        case .available:
            return "Model is ready for local generation."
        case .modelUnavailable:
            return "Apple Intelligence model is not ready yet."
        case .unsupportedHardware:
            return "Apple Silicon with Neural Engine is required."
        case .unsupportedOperatingSystem:
            return "macOS 26+ is required."
        case .frameworkUnavailable:
            return "FoundationModels framework is unavailable in this build."
        }
    }

    @ViewBuilder
    private func checklistRow(
        title: String,
        subtitle: String,
        completed: Bool,
        buttonTitle: String,
        disableButtonWhenCompleted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(completed ? .green : .secondary)
                .font(.title3)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)
                .disabled(disableButtonWhenCompleted && completed)
        }
    }
}

@MainActor
public final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private(set) var window: NSWindow?

    private let appState: AppState
    private let openAccessibilitySettings: () -> Void
    private let openModelSettings: () -> Void
    private let refreshReadiness: () -> Void

    public init(
        appState: AppState,
        openAccessibilitySettings: @escaping () -> Void,
        openModelSettings: @escaping () -> Void,
        refreshReadiness: @escaping () -> Void
    ) {
        self.appState = appState
        self.openAccessibilitySettings = openAccessibilitySettings
        self.openModelSettings = openModelSettings
        self.refreshReadiness = refreshReadiness
        super.init()
    }

    public func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(
            rootView: OnboardingView(
                appState: appState,
                openAccessibilitySettings: openAccessibilitySettings,
                openModelSettings: openModelSettings,
                refreshReadiness: refreshReadiness
            )
        )

        let newWindow = NSWindow(contentViewController: hosting)
        newWindow.title = "Welcome"
        newWindow.styleMask = [.titled, .closable]
        newWindow.setContentSize(NSSize(width: 560, height: 340))
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func hide() {
        window?.orderOut(nil)
    }

    public func windowWillClose(_ notification: Notification) {
        if appState.isOnboardingPresented {
            appState.dismissOnboarding(markSeen: true)
        }
    }
}
