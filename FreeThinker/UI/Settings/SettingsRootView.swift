import SwiftUI

@MainActor
public final class SettingsNavigationState: ObservableObject {
    @Published public var selectedSection: SettingsSection

    public init(selectedSection: SettingsSection = .general) {
        self.selectedSection = selectedSection
    }
}

public struct SettingsRootView: View {
    @ObservedObject private var appState: AppState
    @ObservedObject private var navigationState: SettingsNavigationState

    private let onCheckForUpdates: (() -> Void)?

    public init(
        appState: AppState,
        navigationState: SettingsNavigationState,
        onCheckForUpdates: (() -> Void)? = nil
    ) {
        self.appState = appState
        self.navigationState = navigationState
        self.onCheckForUpdates = onCheckForUpdates
    }

    public var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: sectionSelection) { section in
                Label(section.title, systemImage: iconName(for: section))
                    .accessibilityIdentifier(accessibilityIdentifier(for: section))
                    .tag(section)
            }
            .accessibilityIdentifier(SettingsAccessibility.Identifier.sidebar)
            .frame(minWidth: 220)
        } detail: {
            detailView(for: navigationState.selectedSection)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 760, idealWidth: 840, minHeight: 460, idealHeight: 520)
        .accessibilityIdentifier(SettingsAccessibility.Identifier.root)
    }
}

private extension SettingsRootView {
    var sectionSelection: Binding<SettingsSection?> {
        Binding<SettingsSection?>(
            get: { navigationState.selectedSection },
            set: { navigationState.selectedSection = $0 ?? .general }
        )
    }

    @ViewBuilder
    func detailView(for section: SettingsSection) -> some View {
        switch section {
        case .general:
            GeneralSettingsView(
                appState: appState,
                onCheckForUpdates: onCheckForUpdates
            )
        case .provocation:
            ProvocationSettingsView(appState: appState)
        case .accessibilityHelp:
            AccessibilityHelpSettingsView()
        }
    }

    func iconName(for section: SettingsSection) -> String {
        switch section {
        case .general:
            return "gearshape"
        case .provocation:
            return "text.quote"
        case .accessibilityHelp:
            return "figure.wave"
        }
    }

    func accessibilityIdentifier(for section: SettingsSection) -> String {
        switch section {
        case .general:
            return SettingsAccessibility.Identifier.sectionGeneral
        case .provocation:
            return SettingsAccessibility.Identifier.sectionProvocation
        case .accessibilityHelp:
            return SettingsAccessibility.Identifier.sectionAccessibility
        }
    }
}
