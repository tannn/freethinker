import SwiftUI

/// Shared visual constants used by the floating panel component family.
///
/// Centralising these values ensures all panel sub-views share the same corner radii,
/// spacing scale, and height cap without hard-coded magic numbers.
public enum FloatingPanelDesignTokens {
    public static let cornerRadius: CGFloat = 16
    public static let compactSpacing: CGFloat = 8
    public static let regularSpacing: CGFloat = 12
    public static let wideSpacing: CGFloat = 16
    public static let maxBodyHeight: CGFloat = 220
}

/// A view displayed while the AI generation pipeline is running.
///
/// Shows a circular progress indicator alongside a contextual label that includes the
/// active provocation style name.
public struct FloatingPanelLoadingView: View {
    private let styleDisplayName: String

    /// Creates a loading view for the given style name.
    ///
    /// - Parameter styleDisplayName: The display name of the active provocation style preset.
    ///   The name is lowercased before display.
    public init(styleDisplayName: String) {
        self.styleDisplayName = styleDisplayName.lowercased()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FloatingPanelDesignTokens.regularSpacing) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.accentColor)
                .controlSize(.regular)
                .accessibilityIdentifier(FloatingPanelAccessibility.Identifier.loadingIndicator)
                .accessibilityLabel(FloatingPanelAccessibility.Label.loading)

            Text("Generating a \(styleDisplayName) perspective…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A scrollable card displaying a successful provocation response.
///
/// Renders the response body and, if present, a follow-up question separated by a divider.
/// Tapping the card triggers the copy callback when `canCopy` is `true`.
public struct FloatingPanelResponseCard: View {
    private let content: ProvocationContent
    private let canCopy: Bool
    private let onCopyRequested: () -> Void

    /// Creates a response card for the given provocation content.
    ///
    /// - Parameters:
    ///   - content: The provocation content to display.
    ///   - canCopy: Whether tapping the card should invoke the copy callback. Defaults to `true`.
    ///   - onCopyRequested: Called when the user taps the card and copying is enabled. Defaults to a no-op.
    public init(
        content: ProvocationContent,
        canCopy: Bool = true,
        onCopyRequested: @escaping () -> Void = {}
    ) {
        self.content = content
        self.canCopy = canCopy
        self.onCopyRequested = onCopyRequested
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FloatingPanelDesignTokens.regularSpacing) {

                Text(content.body)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                if let followUpQuestion = content.followUpQuestion {
                    Divider()
                    Text(followUpQuestion)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(FloatingPanelAccessibility.Identifier.copyTarget)
            .accessibilityLabel(FloatingPanelAccessibility.Label.copyTarget)
            .accessibilityHint(FloatingPanelAccessibility.Hint.copyTarget)
            .accessibilityAddTraits(.isButton)
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture().onEnded {
                guard canCopy else {
                    return
                }
                onCopyRequested()
            },
            including: .all
        )
        .frame(maxHeight: FloatingPanelDesignTokens.maxBodyHeight)
        .accessibilityIdentifier(FloatingPanelAccessibility.Identifier.responseCard)
    }
}

/// An inline error callout rendered inside the floating panel.
///
/// Displays an error title, a localised message, and an optional suggested remediation
/// action. The callout uses a lightly tinted red background to draw attention without
/// being visually alarming.
public struct FloatingPanelErrorCallout: View {
    private let message: String
    private let suggestedAction: String?

    /// Creates an error callout with the given message and optional suggested action.
    ///
    /// - Parameters:
    ///   - message: The localised error description to show.
    ///   - suggestedAction: An optional string describing the next step the user can take.
    ///     Defaults to `nil`.
    public init(message: String, suggestedAction: String? = nil) {
        self.message = message
        self.suggestedAction = suggestedAction
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FloatingPanelDesignTokens.compactSpacing) {
            Label("Could not generate provocation", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let suggestedAction {
                Text(suggestedAction)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(FloatingPanelDesignTokens.regularSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.red.opacity(0.12))
        )
        .accessibilityIdentifier(FloatingPanelAccessibility.Identifier.errorCallout)
        .accessibilityLabel(FloatingPanelAccessibility.Label.error)
        .accessibilityHint(FloatingPanelAccessibility.Hint.error)
    }
}
