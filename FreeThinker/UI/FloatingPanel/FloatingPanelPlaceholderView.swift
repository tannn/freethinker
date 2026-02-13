import SwiftUI

struct FloatingPanelPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Provocation Panel")
                .font(.headline)
            Text("Floating panel UI will be implemented in WP02.")
                .font(.body)
        }
        .padding(20)
        .frame(minWidth: 320, minHeight: 180)
    }
}
