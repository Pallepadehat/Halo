import HaloCore
import SwiftUI

struct MenuContent: View {
    @Environment(AgentHub.self) private var agents

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if Helper.isSandboxed {
                Label("This build of Halo Helper is sandboxed, so pairing, Trackpad and agent hooks can't work. Turn off App Sandbox in project.yml and rebuild.", systemImage: "exclamationmark.octagon")
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
            }
            SessionsSection(sessions: agents.sessions)
            Divider()
            PadsSection()
            Divider()
            TrackpadSection()
            Divider()
            IntegrationsSection()
            Divider()
            HStack {
                Button("Check for Updates…") { Updates.shared.checkNow() }
                Spacer()
                Button("Quit Halo") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 340)
    }
}

private struct SessionsSection: View {
    let sessions: [AgentSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Agents")
            if sessions.isEmpty {
                Text("No agents running")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessions) { session in
                    AgentSessionRow(session: session)
                }
            }
        }
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

#Preview {
    let helper = Helper()
    MenuContent()
        .environment(helper.agents)
        .environment(helper.pads)
        .environment(helper.trackpad)
}
