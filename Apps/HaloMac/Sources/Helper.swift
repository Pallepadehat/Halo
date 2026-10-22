import AppKit
import HaloCore
import HaloInput
import HaloMetrics
import HaloProtocol
import HaloTransport

/// Composes the helper's services and routes messages between them.
@MainActor
final class Helper {
    let agents = AgentHub()
    let pads = PadLink(identity: .local(named: Host.current().localizedName ?? String(localized: "Mac")))
    let trackpad = TrackpadAccess()

    private let input = InputInjector()
    /// Kept even with no iPad connected, so Pulse opens with ten minutes of history.
    private var pulse = MetricsHistory()
    private var sampling: Task<Void, Never>?

    func start() {
        agents.onSessionsChange = { [pads] sessions in
            pads.broadcast(.agents(sessions))
        }
        trackpad.onChange = { [pads] isGranted in
            pads.broadcast(.trackpadAvailability(isAvailable: isGranted))
        }
        pads.snapshot = { [unowned self] in
            [
                .agents(agents.sessions),
                .metricsHistory(pulse.samples),
                .trackpadAvailability(isAvailable: trackpad.isGranted),
            ]
        }
        pads.onPointer = { [input] event in
            input.play(event)
        }
        pads.onMessage = { [agents] message in
            switch message {
            case .resolveApproval(let id, let decision):
                agents.resolve(id, with: decision)
            case .hello, .pointer, .ping, .agentAction, .runAction:
                break
            }
        }

        agents.start()
        pads.start()
        trackpad.start()
        sampling = Task { [unowned self] in
            for await sample in MetricsMonitor.samples() {
                pulse.append(sample)
                pads.broadcast(.metrics(sample))
            }
        }
    }
}
