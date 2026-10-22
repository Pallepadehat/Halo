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
            // The icon's iPad, with a badge when an agent needs you.
            Image(systemName: helper.agents.needsAttention ? "ipad.landscape.badge.exclamationmark" : "ipad.landscape")
        }
        .menuBarExtraStyle(.window)
    }
}
