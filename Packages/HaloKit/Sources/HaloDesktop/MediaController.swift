#if os(macOS)
import AppKit
import HaloCore

/// Reads and drives Music and Spotify through their AppleScript dictionaries, the one
/// supported way to talk to both. The system asks for Automation consent per app, once.
///
/// A script is only ever compiled for a player that's running. Merely *compiling* one that
/// names an app makes macOS look it up, which asks "Where is Spotify?" if it isn't installed,
/// and can launch it if it is.
@MainActor
public final class MediaController {
    private var lastActive: MediaSource?
    private var askedForConsent: Set<MediaSource> = []

    public init() {}

    /// Asks for Automation consent the first time each player is seen running, so the system
    /// prompt appears cleanly instead of a poll failing silently. Off the main actor: the call
    /// blocks until the person answers.
    public func requestConsentForRunningPlayers() {
        for source in MediaSource.allCases where source.isRunning && !askedForConsent.contains(source) {
            askedForConsent.insert(source)
            Task.detached(priority: .utility) { _ = Self.determineConsent(for: source.bundleIdentifier, prompting: true) }
        }
    }

    /// `noErr` when allowed, `errAEEventNotPermitted` when refused, `errAEEventWouldRequireUserConsent` when not yet asked.
    nonisolated static func determineConsent(for bundleIdentifier: String, prompting: Bool) -> OSStatus {
        var target = AEAddressDesc()
        let status = bundleIdentifier.withCString { identifier in
            AECreateDesc(typeApplicationBundleID, identifier, strlen(identifier), &target)
        }
        guard status == noErr else { return OSStatus(status) }
        defer { AEDisposeDesc(&target) }
        return AEDeterminePermissionToAutomateTarget(&target, typeWildCard, typeWildCard, prompting)
    }

    /// Whichever player is playing, else the one that played last, else whichever has a track.
    public func nowPlaying() -> NowPlaying? {
        let reports = MediaSource.allCases.filter(\.isRunning).compactMap(read)
        let chosen = reports.first(where: \.isPlaying)
            ?? reports.first { $0.source == lastActive }
            ?? reports.first
        if let chosen, chosen.isPlaying { lastActive = chosen.source }
        return chosen
    }

    public func perform(_ command: MediaCommand, on source: MediaSource?) {
        guard let source = [source, lastActive].compactMap(\.self).first(where: \.isRunning)
            ?? MediaSource.allCases.first(where: \.isRunning)
        else { return }
        let verb = switch command {
        case .playPause: "playpause"
        case .next: "next track"
        case .previous: "previous track"
        }
        run("tell application \"\(source.applicationName)\" to \(verb)")
    }

    /// The current track's artwork as a small JPEG, for the backdrop and the widget.
    public func artwork(for track: NowPlaying) async -> Data? {
        guard track.source.isRunning else { return nil }
        switch track.source {
        case .music:
            let data = run("""
            tell application "Music"
                with timeout of 2 seconds
                    get raw data of artwork 1 of current track
                end timeout
            end tell
            """)?.data
            return data.flatMap(NSImage.init(data:)).flatMap { ImageEncoding.jpeg($0, maxDimension: 600) }
        case .spotify:
            guard let address = run("tell application \"Spotify\" to get artwork url of current track")?.stringValue,
                  let url = URL(string: address),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = NSImage(data: data)
            else { return nil }
            return ImageEncoding.jpeg(image, maxDimension: 600)
        }
    }

    private func read(_ source: MediaSource) -> NowPlaying? {
        guard let result = run(source.statusScript) else { return nil }
        let fields = (0..<result.numberOfItems).map { result.atIndex($0 + 1)?.stringValue ?? "" }
        return NowPlayingParser.parse(fields, from: source)
    }

    @discardableResult
    private func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }
}

/// Turns the status scripts' field lists into `NowPlaying`. Pure, so it's tested.
enum NowPlayingParser {
    /// Fields: state, track ID, title, artist, album, duration, position.
    static func parse(_ fields: [String], from source: MediaSource, at date: Date = .now) -> NowPlaying? {
        guard fields.count >= 7, let state = fields.first, state == "playing" || state == "paused" else { return nil }
        // Spotify reports duration in milliseconds, Music in seconds.
        let durationScale = source == .spotify ? 1000.0 : 1
        return NowPlaying(
            source: source,
            trackID: fields[1],
            title: fields[2],
            artist: fields[3],
            album: fields[4],
            duration: Double(fields[5].replacingOccurrences(of: ",", with: ".")).map { $0 / durationScale },
            isPlaying: state == "playing",
            position: Double(fields[6].replacingOccurrences(of: ",", with: ".")),
            positionDate: date
        )
    }
}

extension MediaSource {
    var bundleIdentifier: String {
        switch self {
        case .music: "com.apple.Music"
        case .spotify: "com.spotify.client"
        }
    }

    /// Asked of the system directly, never through AppleScript.
    public var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

}

private extension MediaSource {
    var applicationName: String {
        switch self {
        case .music: "Music"
        case .spotify: "Spotify"
        }
    }

    var statusScript: String {
        let trackID = self == .music ? "persistent ID of t" : "id of t"
        return """
        tell application "\(applicationName)"
            with timeout of 1 second
                set s to player state as string
                if s is "stopped" then return {s}
                set t to current track
                return {s, (\(trackID)) as string, name of t, artist of t, album of t, (duration of t) as string, (player position) as string}
            end timeout
        end tell
        """
    }
}
#endif
