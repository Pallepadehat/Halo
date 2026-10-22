import SwiftUI

/// Menu bar helper: owns all Mac-side logic (metrics, agent adapters, input control, transport).
@main
struct HaloMacApp: App {
    @State private var helper: Helper

    init() {
        let helper = Helper()
        helper.start()
        _helper = State(initialValue: helper)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environment(helper.agents)
                .environment(helper.pads)
                .environment(helper.trackpad)
        } label: {
            Image(systemName: helper.agents.needsAttention ? "circle.inset.filled" : "circle")
        }
        .menuBarExtraStyle(.window)
    }
}
