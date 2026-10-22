import HaloCore
import HaloProtocol
import Observation

/// Everything the iPad shows. State arrives from the Mac; the iPad only draws and senses touch.
@MainActor
@Observable
final class PadModel {
    var mode: Mode = .zen
    private(set) var metrics: SystemMetrics = .empty
    private(set) var agents: [AgentSession] = []

    let link: MacLink
    @ObservationIgnored private let suggester = ModeSuggester()

    init(link: MacLink) {
        self.link = link
        link.onMessage = { [weak self] message in self?.apply(message) }
        link.onDisconnect = { [weak self] in self?.agents = [] }
    }

    func start() {
        link.start()
    }

    func resolve(_ request: ApprovalRequest, with decision: ApprovalDecision) {
        link.send(.resolveApproval(id: request.id, decision: decision))
    }

    private func apply(_ message: MacMessage) {
        switch message {
        case .hello:
            break
        case .metrics(let metrics):
            self.metrics = metrics
        case .agents(let sessions):
            let previous = agents
            agents = sessions
            if let suggestion = suggester.suggestion(showing: mode, previous: previous, current: sessions) {
                mode = suggestion
            }
        }
    }
}
