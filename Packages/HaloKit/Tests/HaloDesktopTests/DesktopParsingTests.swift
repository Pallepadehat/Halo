import Foundation
import Testing
import HaloCore
@testable import HaloDesktop

@Suite struct DockAppsTests {
    private func tile(_ name: String, bundle: String?, url: String) -> [String: Any] {
        var data: [String: Any] = ["file-label": name, "file-data": ["_CFURLString": url]]
        data["bundle-identifier"] = bundle
        return ["tile-data": data]
    }

    @Test func readsTilesInDockOrder() {
        let apps = DockApps.parse([
            tile("Safari", bundle: "com.apple.Safari", url: "file:///Applications/Safari.app/"),
            tile("Notes", bundle: "com.apple.Notes", url: "file:///System/Applications/Notes.app/"),
        ])
        #expect(apps.map(\.item.name) == ["Safari", "Notes"])
        #expect(apps.first?.url.path(percentEncoded: false) == "/Applications/Safari.app/")
    }

    @Test func skipsMalformedAndDuplicateTilesAndFinder() {
        let apps = DockApps.parse([
            ["tile-data": ["file-label": "Broken"]],
            tile("Finder", bundle: "com.apple.finder", url: "file:///System/Library/CoreServices/Finder.app/"),
            tile("Music", bundle: "com.apple.Music", url: "file:///System/Applications/Music.app/"),
            tile("Music", bundle: "com.apple.Music", url: "file:///System/Applications/Music.app/"),
        ])
        #expect(apps.map(\.item.id) == ["com.apple.Music"])
    }

    @Test func fallsBackToThePathForAppsWithoutABundleID() {
        let apps = DockApps.parse([tile("Tool", bundle: nil, url: "file:///Applications/Tool.app/")])
        #expect(apps.first?.item.id == "/Applications/Tool.app/")
    }
}

@Suite struct NowPlayingParserTests {
    @Test func parsesMusic() throws {
        let track = try #require(NowPlayingParser.parse(
            ["playing", "ABC", "Daylight", "Orbit Sessions", "Light", "245.5", "12.25"], from: .music
        ))
        #expect(track.title == "Daylight")
        #expect(track.duration == 245.5)
        #expect(track.position == 12.25)
        #expect(track.isPlaying)
    }

    @Test func convertsSpotifyMillisecondsAndLocaleCommas() throws {
        let track = try #require(NowPlayingParser.parse(
            ["paused", "spotify:track:1", "Song", "Artist", "Album", "200000", "3,5"], from: .spotify
        ))
        #expect(track.duration == 200)
        #expect(track.position == 3.5)
        #expect(!track.isPlaying)
    }

    @Test func stoppedOrEmptyMeansNothingPlaying() {
        #expect(NowPlayingParser.parse(["stopped"], from: .music) == nil)
        #expect(NowPlayingParser.parse([], from: .spotify) == nil)
    }
}

@Suite struct DeckCatalogTests {
    @Test func parsesTheShortcutsList() {
        #expect(DeckCatalog.parseShortcutList("Focus On\n  Morning routine \n\n") == ["Focus On", "Morning routine"])
    }

    @Test func splitsActionIDsOnTheFirstDotOnly() {
        let (kind, name) = DeckCatalog.split("script.deploy.staging.sh")
        #expect(kind == "script")
        #expect(name == "deploy.staging.sh")
    }

    @Test func titlesScriptsReadably() {
        #expect(DeckCatalog.scriptTitle("deploy-staging_now.sh") == "Deploy staging now")
    }
}

@Suite struct UpNextTests {
    let now = Date(timeIntervalSinceReferenceDate: 0)

    private func event(_ title: String, in minutes: Double, allDay: Bool = false) -> UpcomingEvent {
        UpcomingEvent(title: title, start: now.addingTimeInterval(minutes * 60), end: now.addingTimeInterval(minutes * 60 + 1800),
                      isAllDay: allDay, location: nil, calendarColor: nil)
    }

    @Test func prefersTheSoonestTimedEventOverAllDayOnes() {
        let next = UpNext.mostRelevant([event("Holiday", in: -60, allDay: true), event("Review", in: 90), event("Standup", in: 15)])
        #expect(next?.title == "Standup")
    }
}

@Suite struct SoftwareDimmingTests {
    @Test func theBottomOfTheSliderIsDimNotBlack() {
        #expect(DisplayBrightness.softwareLevel(for: 0) == DisplayBrightness.softwareFloor)
        #expect(DisplayBrightness.softwareLevel(for: 1) == 1)
    }

    @Test func sliderAndLevelRoundTrip() {
        for value in stride(from: 0.0, through: 1.0, by: 0.25) {
            let level = DisplayBrightness.softwareLevel(for: value)
            #expect(abs(DisplayBrightness.sliderValue(forSoftwareLevel: level) - value) < 1e-9)
        }
    }
}
