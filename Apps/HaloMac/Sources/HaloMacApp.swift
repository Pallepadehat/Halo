import SwiftUI

/// Menu bar helper: owns all Mac-side logic (metrics, agent adapters, input control, transport).
@main
struct HaloMacApp: App {
    @State private var agents: AgentHub

    init() {
        let agents = AgentHub()
        agents.start()
        _agents = State(initialValue: agents)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environment(agents)
        } label: {
            Image(systemName: agents.needsAttention ? "circle.inset.filled" : "circle")
        }
        .menuBarExtraStyle(.window)
    }
}
