import HaloCore
import SwiftUI

struct AgentSessionRow: View {
    let session: AgentSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                StatusDot(status: session.status)
                Text(session.title)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(session.tool.displayName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            ForEach(session.pendingApprovals) { request in
                ApprovalCard(request: request)
            }

            if session.pendingApprovals.isEmpty, let message = session.latestMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct ApprovalCard: View {
    @Environment(AgentHub.self) private var agents
    let request: ApprovalRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(request.summary)
                .font(.callout.monospaced())
                .lineLimit(3)
            if let detail = request.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(request.toolName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Deny") { agents.resolve(request.id, with: .deny(reason: nil)) }
                Button("Allow") { agents.resolve(request.id, with: .allow) }
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 8))
    }
}

private struct StatusDot: View {
    let status: AgentStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .accessibilityLabel(label)
    }

    private var color: Color {
        switch status {
        case .idle: .secondary
        case .running: .green
        case .waitingForApproval: .orange
        case .waitingForReply: .yellow
        }
    }

    private var label: LocalizedStringKey {
        switch status {
        case .idle: "Idle"
        case .running: "Running"
        case .waitingForApproval: "Waiting for approval"
        case .waitingForReply: "Waiting for you"
        }
    }
}
