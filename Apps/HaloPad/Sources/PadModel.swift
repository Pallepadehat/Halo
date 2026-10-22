import HaloCore
import HaloProtocol
import Observation

/// Everything the iPad shows. State arrives from the Mac; the iPad only draws and senses touch.
@MainActor
@Observable
final class PadModel {
    var mode: Mode = .zen
    private(set) var pulse = MetricsHistory()
    private(set) var agents: [AgentSession] = []

    var metrics: SystemMetrics {
        pulse.latest ?? .empty
    }

    let link: MacLink
    @ObservationIgnored private let suggester = ModeSuggester()

    init(link: MacLink) {
        self.link = link
        link.onMessage = { [weak self] message in self?.apply(message) }
        link.onDisconnect = { [weak self] in
            self?.agents = []
            self?.pulse = MetricsHistory()
        }
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
        case .metrics(let sample):
            pulse.append(sample)
        case .metricsHistory(let samples):
            pulse.replace(with: samples)
        case .agents(let sessions):
            let previous = agents
            agents = sessions
            if let suggestion = suggester.suggestion(showing: mode, previous: previous, current: sessions) {
                mode = suggestion
            }
        }
    }
}

#if DEBUG
extension PadModel {
    static func demo(showing mode: Mode = .zen) -> PadModel {
        let model = PadModel(link: .demo())
        model.apply(.metricsHistory(DemoData.metricsHistory()))
        model.apply(.agents(DemoData.agents()))
        model.mode = mode
        return model
    }
}
#endif
