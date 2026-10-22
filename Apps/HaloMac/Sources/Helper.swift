import AppKit
import HaloProtocol
import HaloTransport

/// Composes the helper's services and routes messages between them.
@MainActor
final class Helper {
    let agents = AgentHub()
    let pads = PadLink(identity: .local(named: Host.current().localizedName ?? String(localized: "Mac")))

    func start() {
        agents.onSessionsChange = { [pads] sessions in
            pads.broadcast(.agents(sessions))
        }
        pads.snapshot = { [agents] in
            [.agents(agents.sessions)]
        }
        pads.onMessage = { [agents] message in
            switch message {
            case .resolveApproval(let id, let decision):
                agents.resolve(id, with: decision)
            case .hello, .pointer, .agentAction, .runAction:
                break
            }
        }

        agents.start()
        pads.start()
    }
}
