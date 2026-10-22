import HaloCore
import SwiftUI

struct IntegrationsSection: View {
    @Environment(AgentHub.self) private var agents

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Integrations")
            ForEach(AgentTool.allCases, id: \.self) { tool in
                IntegrationRow(tool: tool)
            }
        }
    }
}

private struct IntegrationRow: View {
    @Environment(AgentHub.self) private var agents
    let tool: AgentTool

    private var state: AgentHub.IntegrationState {
        agents.integrations[tool] ?? .notInstalled
    }

    private var isEnabled: Binding<Bool> {
        Binding { [agents, tool] in
            agents.integrations[tool] == .installed
        } set: { [agents, tool] enabled in
            agents.setIntegration(tool, enabled: enabled)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(tool.displayName, isOn: isEnabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(isFailure ? .red : .secondary)
            }
        }
    }

    private var isFailure: Bool {
        if case .failed = state { true } else { false }
    }

    private var caption: LocalizedStringKey? {
        switch (state, tool) {
        case (.failed(let message), _): "\(message)"
        case (.installed, .codex): "Run /hooks in Codex to trust Halo's hooks."
        case (.installed, .cursor): "Read-only: Cursor can't be approved from Halo."
        default: nil
        }
    }
}
