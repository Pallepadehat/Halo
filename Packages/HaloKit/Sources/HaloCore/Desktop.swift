import Foundation

// The Mac-side things an iPad can see and drive: apps, media, controls, actions, calendar.

/// An app from the Mac's Dock.
public struct LaunchItem: Codable, Sendable, Hashable, Identifiable {
    /// The app's bundle identifier, or its path when it has none.
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public enum MediaSource: String, Codable, Sendable, CaseIterable {
    case music
    case spotify

    public var displayName: String {
        switch self {
        case .music: "Music"
        case .spotify: "Spotify"
        }
    }
}

/// What's playing on the Mac.
public struct NowPlaying: Codable, Sendable, Hashable {
    public let source: MediaSource
    /// Stable per track; artwork is sent once per track and keyed by this.
    public let trackID: String
    public let title: String
    public let artist: String
    public let album: String
    public let duration: TimeInterval?
    public let isPlaying: Bool
    /// Playback position at `positionDate`, so the iPad can advance progress without polling.
    public let position: TimeInterval?
    public let positionDate: Date

    public init(
        source: MediaSource,
        trackID: String,
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval?,
        isPlaying: Bool,
        position: TimeInterval?,
        positionDate: Date = .now
    ) {
        self.source = source
        self.trackID = trackID
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.isPlaying = isPlaying
        self.position = position
        self.positionDate = positionDate
    }

    /// Where playback is at `date`, extrapolated from the last report while playing.
    public func position(at date: Date) -> TimeInterval? {
        guard let position else { return nil }
        let elapsed = isPlaying ? date.timeIntervalSince(positionDate) : 0
        return min(position + max(elapsed, 0), duration ?? .infinity)
    }
}

public enum MediaCommand: String, Codable, Sendable {
    case playPause, next, previous
}

/// Output volume and display brightness, each `nil` when this Mac can't control it.
public struct SystemControls: Codable, Sendable, Hashable {
    public var volume: Double?
    public var isMuted: Bool
    public var outputName: String?
    public var brightness: Double?
    public var displayName: String?
    /// The display has no brightness control of its own, so Halo dims it in software.
    public var isBrightnessSoftware: Bool

    public init(
        volume: Double?,
        isMuted: Bool,
        outputName: String?,
        brightness: Double?,
        displayName: String?,
        isBrightnessSoftware: Bool = false
    ) {
        self.volume = volume
        self.isMuted = isMuted
        self.outputName = outputName
        self.brightness = brightness
        self.displayName = displayName
        self.isBrightnessSoftware = isBrightnessSoftware
    }

    public static let unavailable = SystemControls(volume: nil, isMuted: false, outputName: nil, brightness: nil, displayName: nil)
}

/// A one-tap action on the Deck.
public struct DeckAction: Codable, Sendable, Hashable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case builtIn, shortcut, script
    }

    public let id: String
    public let title: String
    /// An SF Symbol name.
    public let symbol: String
    public let kind: Kind

    public init(id: String, title: String, symbol: String, kind: Kind) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.kind = kind
    }
}

/// The next thing on the calendar, for the clock.
public struct UpcomingEvent: Codable, Sendable, Hashable {
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let location: String?
    /// `#RRGGBB`, the calendar's own colour.
    public let calendarColor: String?

    public init(title: String, start: Date, end: Date, isAllDay: Bool, location: String?, calendarColor: String?) {
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.calendarColor = calendarColor
    }
}
