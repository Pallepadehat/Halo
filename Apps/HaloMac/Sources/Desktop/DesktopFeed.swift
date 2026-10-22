import AppKit
import HaloCore
import HaloDesktop
import HaloProtocol

/// Keeps connected iPads in sync with the Mac's desktop: wallpaper, Dock, media, volume and
/// brightness, Deck actions and the calendar. Sends only what changed, and does the frequent
/// polling only while an iPad is listening.
@MainActor
final class DesktopFeed {
    /// Media and controls move under a person's fingers; check often while someone's watching.
    static let liveInterval: Duration = .seconds(1)
    /// Wallpaper, Dock and Deck rarely change.
    static let backgroundInterval: Duration = .seconds(20)

    var broadcast: (MacMessage) -> Void = { _ in }
    var hasListeners: () -> Bool = { false }

    private let media = MediaController()
    private let upNext = UpNext()
    private var apps: [String: DockApp] = [:]
    private var launcher: [LaunchItem] = []
    private var icons: [LaunchItem.ID: Data] = [:]
    private var wallpaper: (signature: String, jpeg: Data)?
    private var nowPlaying: NowPlaying?
    private var artwork: (trackID: String, jpeg: Data)?
    private var controls = SystemControls.unavailable
    private var deck: [DeckAction] = []
    private var next: UpcomingEvent?
    private var loops: [Task<Void, Never>] = []

    func start() {
        // Software dimming lives in the display's gamma; never leave it behind.
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { DisplayBrightness.restoreSoftwareDimming() }
        }
        upNext.onChange { [weak self] in self?.refreshCalendar() }
        loops = [
            Task { [weak self] in
                await self?.upNext.requestAccess()
                self?.refreshCalendar()
            },
            repeating(every: Self.liveInterval) { feed in
                guard feed.hasListeners() else { return }
                feed.refreshMedia()
                feed.refreshControls()
            },
            repeating(every: Self.backgroundInterval) { feed in
                feed.refreshWallpaper()
                feed.refreshLauncher()
                feed.refreshCalendar()
                await feed.refreshDeck()
            },
        ]
    }

    /// Everything a newly connected iPad needs to draw its first frame.
    var snapshot: [MacMessage] {
        var messages: [MacMessage] = [.launcher(launcher), .controls(controls), .deck(deck), .upNext(next), .nowPlaying(nowPlaying)]
        if let wallpaper { messages.append(.wallpaper(jpeg: wallpaper.jpeg)) }
        if let artwork { messages.append(.artwork(trackID: artwork.trackID, jpeg: artwork.jpeg)) }
        messages += launcher.compactMap { item in icons[item.id].map { .appIcon(id: item.id, png: $0) } }
        return messages
    }

    /// Returns `false` for messages this feed doesn't own.
    func handle(_ message: PadMessage) -> Bool {
        switch message {
        case .launch(let id):
            if let app = apps[id] { DockApps.launch(app) }
        case .media(let command):
            media.perform(command, on: nowPlaying?.source)
            refreshMedia()
        case .setVolume(let volume):
            SystemAudio.setVolume(volume)
            refreshControls()
        case .toggleMute:
            SystemAudio.toggleMute()
            refreshControls()
        case .setBrightness(let brightness):
            DisplayBrightness.setBrightness(brightness)
            refreshControls()
        case .runAction(let id):
            Task { [media] in await DeckCatalog.run(id, media: media) }
        default:
            return false
        }
        return true
    }

    // MARK: - Refreshing

    private func refreshMedia() {
        media.requestConsentForRunningPlayers()
        let current = media.nowPlaying()
        guard current.differsMeaningfully(from: nowPlaying) else { return }
        nowPlaying = current
        broadcast(.nowPlaying(current))

        guard let current, current.trackID != artwork?.trackID else { return }
        Task {
            guard let jpeg = await media.artwork(for: current), nowPlaying?.trackID == current.trackID else { return }
            artwork = (current.trackID, jpeg)
            broadcast(.artwork(trackID: current.trackID, jpeg: jpeg))
        }
    }

    private func refreshControls() {
        let audio = SystemAudio.current()
        let display = DisplayBrightness.current()
        let current = SystemControls(
            volume: audio.volume, isMuted: audio.isMuted, outputName: audio.deviceName,
            brightness: display.brightness, displayName: display.displayName, isBrightnessSoftware: display.isSoftware
        )
        guard current != controls else { return }
        controls = current
        broadcast(.controls(current))
    }

    private func refreshWallpaper() {
        guard let signature = Wallpaper.currentSignature(), signature != wallpaper?.signature,
              let jpeg = Wallpaper.currentJPEG()
        else { return }
        wallpaper = (signature, jpeg)
        broadcast(.wallpaper(jpeg: jpeg))
    }

    private func refreshLauncher() {
        let current = DockApps.current()
        let items = current.map(\.item)
        guard items != launcher else { return }
        apps = Dictionary(current.map { ($0.item.id, $0) }, uniquingKeysWith: { first, _ in first })
        launcher = items
        broadcast(.launcher(items))
        for app in current where icons[app.item.id] == nil {
            guard let png = DockApps.iconPNG(for: app) else { continue }
            icons[app.item.id] = png
            broadcast(.appIcon(id: app.item.id, png: png))
        }
    }

    private func refreshDeck() async {
        let current = await DeckCatalog.actions()
        guard current != deck else { return }
        deck = current
        broadcast(.deck(current))
    }

    private func refreshCalendar() {
        let current = upNext.next()
        guard current != next else { return }
        next = current
        broadcast(.upNext(current))
    }

    private func repeating(every interval: Duration, _ body: @escaping @MainActor (DesktopFeed) async -> Void) -> Task<Void, Never> {
        Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await body(self)
                try? await Task.sleep(for: interval)
            }
        }
    }
}

private extension Optional where Wrapped == NowPlaying {
    /// Ignores the position creeping forward between polls; the iPad extrapolates that itself.
    func differsMeaningfully(from other: NowPlaying?) -> Bool {
        switch (self, other) {
        case (nil, nil):
            return false
        case let (current?, previous?):
            guard current.trackID == previous.trackID, current.isPlaying == previous.isPlaying,
                  current.title == previous.title, current.duration == previous.duration
            else { return true }
            let expected = previous.position(at: current.positionDate) ?? 0
            return abs((current.position ?? 0) - expected) > 2
        default:
            return true
        }
    }
}
