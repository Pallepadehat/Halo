import SwiftUI
import HaloCore
import HaloProtocol

/// Menu bar helper: owns all Mac-side logic (metrics, agent adapters, input control, transport).
@main
struct HaloMacApp: App {
    var body: some Scene {
        MenuBarExtra("Halo", systemImage: "circle.circle") {
            MenuContent()
        }
    }
}

struct MenuContent: View {
    var body: some View {
        Text("Halo helper — protocol v\(haloProtocolVersion)")
        Text("No iPad paired")
        Divider()
        Button("Quit Halo") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
