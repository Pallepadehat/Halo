#if os(macOS)
import AppKit
import HaloCore

/// Reads and drives Music and Spotify through their AppleScript dictionaries, the one
/// supported way to talk to both. The system asks for Automation consent per app, once.
///
/// Scripts check `is running` first, so polling never launches a player.
@MainActor
public final class MediaController {
    private var lastActive: MediaSource?

    public init() {}

    /// Whichever player is playing, else the one that played last, else whichever has a track.
    public func nowPlaying() -> NowPlaying? {
        let reports = MediaSource.allCases.compactMap(read)
        let chosen = reports.first(where: \.isPlaying)
            ?? reports.first { $0.source == lastActive }
            ?? reports.first
        if let chosen, chosen.isPlaying { lastActive = chosen.source }
        return chosen
    }

    public func perform(_ command: MediaCommand, on source: MediaSource?) {
        let source = source ?? lastActive ?? .music
        let verb = switch command {
        case .playPause: "playpause"
        case .next: "next track"
        case .previous: "previous track"
        }
        run("if application \"\(source.applicationName)\" is running then tell application \"\(source.applicationName)\" to \(verb)")
    }

    /// The current track's artwork as a small JPEG, for the backdrop and the widget.
    public func artwork(for track: NowPlaying) async -> Data? {
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
        if application "\(applicationName)" is running then
            tell application "\(applicationName)"
                with timeout of 1 second
                    set s to player state as string
                    if s is "stopped" then return {s}
                    set t to current track
                    return {s, (\(trackID)) as string, name of t, artist of t, album of t, (duration of t) as string, (player position) as string}
                end timeout
            end tell
        end if
        return {}
        """
    }
}
#endif
