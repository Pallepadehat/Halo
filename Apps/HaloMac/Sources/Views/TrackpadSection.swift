import SwiftUI

struct TrackpadSection: View {
    @Environment(TrackpadAccess.self) private var access
    @Environment(\.openURL) private var openURL

    private static let accessibilitySettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Trackpad")
            if access.isGranted {
                Label("Your iPad can control the pointer.", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
                Text("Allow Halo Helper under Accessibility so your iPad can move the pointer.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Allow…") { access.request() }
                    Button("Open Accessibility Settings…") { openURL(Self.accessibilitySettings) }
                        .buttonStyle(.link)
                }
            }
        }
    }
}
