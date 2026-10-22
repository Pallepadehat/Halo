import HaloCore
import SwiftUI

/// Every agent conversation, the ones that need you first. Approve or deny right here.
struct AgentsWidget: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Header(count: model.agents.filter { $0.status != .idle }.count)
            if model.agents.isEmpty {
                WidgetUnavailable(symbol: "sparkles", message: "Claude Code, Codex and Cursor sessions appear here.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.agents) { session in
                            AgentRow(session: session)
                            if session.id != model.agents.last?.id {
                                Rectangle().fill(.inkHairline).frame(height: 1)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.horizontal, 12)
        .animation(.halo, value: model.agents)
    }
}

private struct Header: View {
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(count, format: .number.precision(.integerLength(2)))
                .font(.hero(34))
                .foregroundStyle(.ink)
                .contentTransition(.numericText(value: Double(count)))
            Text("In focus")
                .eyebrowStyle()
                .foregroundStyle(.inkTertiary)
        }
    }
}

private struct AgentRow: View {
    @Environment(PadModel.self) private var model
    let session: AgentSession

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            StatusGlyph(status: session.status)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text(statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusColor)
                Text(session.title)
                    .font(.body)
                    .foregroundStyle(.ink)
                    .lineLimit(1)
                if let request = session.pendingApprovals.first {
                    ApprovalControls(request: request, canAnswer: session.tool.supportsApprovals)
                        .padding(.top, 6)
                } else if let message = session.latestMessage, session.status == .waitingForReply {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.inkSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 12)
            Text([session.project, session.tool.displayName].compactMap(\.self).joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.inkTertiary)
                .padding(.top, 3)
        }
        .padding(.vertical, 16)
        .contentShape(.rect)
    }

    private var statusText: LocalizedStringKey {
        switch session.status {
        case .idle: "Idle"
        case .running: "In progress"
        case .waitingForApproval: session.pendingApprovals.isEmpty ? "Answer on your Mac" : "Approval needed"
        case .waitingForReply: "Your turn"
        }
    }

    private var statusColor: Color {
        switch session.status {
        case .running: .progress
        case .waitingForApproval, .waitingForReply: .attention
        case .idle: .inkTertiary
        }
    }
}

private struct StatusGlyph: View {
    let status: AgentStatus

    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.06))
            switch status {
            case .running:
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(Color.progress, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .rotationEffect(.degrees(120))
                Circle().fill(Color.progress).frame(width: 5, height: 5)
            case .waitingForApproval:
                Text("!").font(.system(size: 13, weight: .semibold)).foregroundStyle(.attention)
            case .waitingForReply:
                Image(systemName: "text.bubble").font(.system(size: 11)).foregroundStyle(.attention)
            case .idle:
                Circle().fill(.inkTertiary).frame(width: 5, height: 5)
            }
        }
        .frame(width: 28, height: 28)
    }
}

private struct ApprovalControls: View {
    @Environment(PadModel.self) private var model
    let request: ApprovalRequest
    let canAnswer: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(request.summary)
                .font(.callout.monospaced())
                .foregroundStyle(.ink)
                .lineLimit(3)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.2), in: .rect(cornerRadius: 10, style: .continuous))
            if canAnswer {
                HStack(spacing: 10) {
                    Button("Deny") { model.resolve(request, with: .deny(reason: nil)) }
                        .buttonStyle(.glass)
                    Button("Allow") { model.resolve(request, with: .allow) }
                        .buttonStyle(.glassProminent)
                        .tint(.attention)
                }
                .controlSize(.large)
            }
        }
    }
}
