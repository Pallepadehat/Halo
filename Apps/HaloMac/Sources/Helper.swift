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

    /// The helper can't work sandboxed (see project.yml). Surfaced in the menu so a stray
    /// Signing & Capabilities change is obvious instead of breaking pairing silently.
    static let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil

    private let input = InputInjector()
    private let desktop = DesktopFeed()
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
        desktop.broadcast = { [pads] message in
            pads.broadcast(message)
        }
        desktop.hasListeners = { [pads] in
            !pads.connectedPads.isEmpty
        }
        pads.snapshot = { [unowned self] in
            [
                .agents(agents.sessions),
                .metricsHistory(pulse.samples),
                .trackpadAvailability(isAvailable: trackpad.isGranted),
            ] + desktop.snapshot
        }
        pads.onPointer = { [input] event in
            input.play(event)
        }
        pads.onMessage = { [agents, desktop] message in
            switch message {
            case .resolveApproval(let id, let decision):
                agents.resolve(id, with: decision)
            case .agentAction(let session, .bringForward):
                agents.bringForward(session)
            default:
                _ = desktop.handle(message)
            }
        }

        Updates.shared.start()
        agents.start()
        pads.start()
        trackpad.start()
        desktop.start()
        #if DEBUG
        // `-HaloBeginPairing` opens the pairing window at launch, for testing without the menu.
        if ProcessInfo.processInfo.arguments.contains("-HaloBeginPairing") { pads.beginPairing() }
        #endif
        sampling = Task { [unowned self] in
            for await sample in MetricsMonitor.samples() {
                pulse.append(sample)
                pads.broadcast(.metrics(sample))
            }
        }
    }
}
