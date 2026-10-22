import HaloCore
import SwiftUI

struct AgentsView: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        if model.agents.isEmpty {
            ContentUnavailableView(
                "No agents running",
                systemImage: "sparkles",
                description: Text("Sessions from Claude Code, Codex and Cursor appear here.")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(model.agents) { session in
                        AgentCard(session: session)
                    }
                }
                .padding(32)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .animation(.halo, value: model.agents)
        }
    }
}

private struct AgentCard: View {
    let session: AgentSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.haloInk)
                        .lineLimit(1)
                    Text([session.project, session.tool.displayName].compactMap(\.self).joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(session: session)
            }

            ForEach(session.pendingApprovals) { request in
                ApprovalPanel(request: request)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if session.pendingApprovals.isEmpty, let message = session.latestMessage {
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(24)
        .background(.haloSurface, in: .rect(cornerRadius: 24))
    }
}

private struct ApprovalPanel: View {
    @Environment(PadModel.self) private var model
    let request: ApprovalRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(request.toolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.haloAttention)
                    .textCase(.uppercase)
                Text(request.summary)
                    .font(.title3.monospaced())
                    .foregroundStyle(.haloInk)
                    .lineLimit(4)
                if let detail = request.detail {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button("Deny", role: .destructive) {
                    model.resolve(request, with: .deny(reason: nil))
                }
                .buttonStyle(.bordered)

                Button("Allow") {
                    model.resolve(request, with: .allow)
                }
                .buttonStyle(.borderedProminent)
                .tint(.haloAttention)
            }
            .controlSize(.extraLarge)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .background(Color.haloAttention.opacity(0.08), in: .rect(cornerRadius: 18))
    }
}

private struct StatusBadge: View {
    let session: AgentSession

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(session.needsAttention ? .haloAttention : .secondary)
            .symbolEffect(.pulse, isActive: session.status == .running)
    }

    private var title: LocalizedStringKey {
        switch session.status {
        case .idle: "Idle"
        case .running: "Working"
        case .waitingForApproval: session.pendingApprovals.isEmpty ? "Answer on your Mac" : "Needs approval"
        case .waitingForReply: "Your turn"
        }
    }

    private var symbol: String {
        switch session.status {
        case .idle: "moon"
        case .running: "ellipsis"
        case .waitingForApproval: "hand.raised"
        case .waitingForReply: "text.bubble"
        }
    }
}
