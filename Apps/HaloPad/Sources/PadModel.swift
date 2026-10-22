import Observation
import HaloCore

@MainActor
@Observable
final class PadModel {
    var mode: Mode = .zen
    var userOverride: Mode?
    var connectedMacName: String?
    var metrics: SystemMetrics = .empty
    var agents: [AgentSession] = []

    private let suggester = ModeSuggester()

    func select(_ mode: Mode) {
        self.mode = mode
        userOverride = mode
    }

    func applySuggestion() {
        if let next = suggester.suggest(current: mode, userOverride: userOverride, agents: agents) {
            mode = next
        }
    }
}
