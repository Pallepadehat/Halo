import HaloCore
import HaloProtocol
import Observation
import UIKit

/// Everything the iPad shows about the Mac. State arrives from the Mac; the iPad only
/// draws and senses touch, and sends intents back.
@MainActor
@Observable
final class PadModel {
    private(set) var pulse = MetricsHistory()
    private(set) var agents: [AgentSession] = []
    /// Whether the Mac may move its pointer (Accessibility consent on the Mac).
    private(set) var isTrackpadAvailable = false
    private(set) var wallpaper: UIImage?
    private(set) var launcher: [LaunchItem] = []
    private(set) var icons: [LaunchItem.ID: UIImage] = [:]
    private(set) var nowPlaying: NowPlaying?
    private(set) var artwork: (trackID: String, image: UIImage)?
    private(set) var controls = SystemControls.unavailable
    private(set) var deck: [DeckAction] = []
    private(set) var upNext: UpcomingEvent?

    var metrics: SystemMetrics {
        pulse.latest ?? .empty
    }

    /// The current track's artwork, once it has arrived.
    var nowPlayingArtwork: UIImage? {
        guard let nowPlaying, let artwork, artwork.trackID == nowPlaying.trackID else { return nil }
        return artwork.image
    }

    /// The session that most deserves a glance: one that needs you, else the busiest.
    var leadingAgent: AgentSession? {
        agents.first
    }

    /// Called when an agent starts needing you, so the dashboard can bring agents forward.
    @ObservationIgnored var onAgentsNeedYou: () -> Void = {}

    let link: MacLink
    @ObservationIgnored private let volumeThrottle = Throttle(interval: .milliseconds(50))
    @ObservationIgnored private let brightnessThrottle = Throttle(interval: .milliseconds(50))
    /// While a finger adjusts a slider, and briefly after, the person's value wins over the
    /// Mac's echo, which always trails a few messages behind and would yank the slider back.
    @ObservationIgnored private var volumeHeldUntil = ContinuousClock.Instant.now
    @ObservationIgnored private var brightnessHeldUntil = ContinuousClock.Instant.now
    private static let adjustmentHold: Duration = .milliseconds(1200)

    init(link: MacLink) {
        self.link = link
        link.onMessage = { [weak self] message in self?.apply(message) }
        link.onDisconnect = { [weak self] in self?.reset() }
    }

    func start() {
        link.start()
    }

    // MARK: - Intents

    func send(_ events: [PointerEvent]) {
        for event in events { link.send(.pointer(event)) }
    }

    func resolve(_ request: ApprovalRequest, with decision: ApprovalDecision) {
        link.send(.resolveApproval(id: request.id, decision: decision))
    }

    func launch(_ item: LaunchItem) {
        link.send(.launch(id: item.id))
    }

    func perform(_ command: MediaCommand) {
        link.send(.media(command))
    }

    func run(_ action: DeckAction) {
        link.send(.runAction(id: action.id))
    }

    func toggleMute() {
        link.send(.toggleMute)
    }

    /// Slider drags fire every frame; the Mac only needs a value every 50 ms, plus the last one.
    func setVolume(_ volume: Double) {
        controls.volume = volume
        controls.isMuted = false
        volumeHeldUntil = .now + Self.adjustmentHold
        volumeThrottle.submit { [link] in link.send(.setVolume(volume)) }
    }

    func setBrightness(_ brightness: Double) {
        controls.brightness = brightness
        brightnessHeldUntil = .now + Self.adjustmentHold
        brightnessThrottle.submit { [link] in link.send(.setBrightness(brightness)) }
    }

    // MARK: - Messages from the Mac

    func apply(_ message: MacMessage) {
        switch message {
        case .hello, .pong:
            break
        case .metrics(let sample):
            pulse.append(sample)
        case .metricsHistory(let samples):
            pulse.replace(with: samples)
        case .agents(let sessions):
            let previous = agents
            agents = sessions
            if AgentAttention.isNewlyNeeded(previous: previous, current: sessions) { onAgentsNeedYou() }
        case .trackpadAvailability(let isAvailable):
            isTrackpadAvailable = isAvailable
        case .wallpaper(let jpeg):
            wallpaper = UIImage(data: jpeg)
        case .launcher(let items):
            launcher = items
        case .appIcon(let id, let png):
            icons[id] = UIImage(data: png)
        case .nowPlaying(let track):
            nowPlaying = track
        case .artwork(let trackID, let jpeg):
            if let image = UIImage(data: jpeg) { artwork = (trackID, image) }
        case .controls(let state):
            var merged = state
            let now = ContinuousClock.now
            if now < volumeHeldUntil {
                merged.volume = controls.volume
                merged.isMuted = controls.isMuted
            }
            if now < brightnessHeldUntil { merged.brightness = controls.brightness }
            controls = merged
        case .deck(let actions):
            deck = actions
        case .upNext(let event):
            upNext = event
        }
    }

    private func reset() {
        agents = []
        pulse = MetricsHistory()
        isTrackpadAvailable = false
        nowPlaying = nil
        controls = .unavailable
    }
}

/// Runs the first submission immediately, then at most one per interval, always ending on the
/// latest: a slider feels instant and the Mac never misses where it stopped.
@MainActor
final class Throttle {
    private let interval: Duration
    private var lastRun: ContinuousClock.Instant?
    private var pending: (() -> Void)?
    private var trailing: Task<Void, Never>?

    init(interval: Duration) {
        self.interval = interval
    }

    func submit(_ work: @escaping () -> Void) {
        let now = ContinuousClock.now
        guard let lastRun, now - lastRun < interval else {
            self.lastRun = now
            work()
            return
        }
        pending = work
        guard trailing == nil else { return }
        trailing = Task { [weak self, interval] in
            try? await Task.sleep(until: lastRun + interval)
            guard let self else { return }
            self.lastRun = .now
            self.pending?()
            self.pending = nil
            self.trailing = nil
        }
    }
}
