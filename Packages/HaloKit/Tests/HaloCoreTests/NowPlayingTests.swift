import Foundation
import Testing
@testable import HaloCore

@Suite struct NowPlayingTests {
    let reported = Date(timeIntervalSinceReferenceDate: 1000)

    func track(isPlaying: Bool) -> NowPlaying {
        NowPlaying(source: .music, trackID: "1", title: "Daylight", artist: "Orbit Sessions", album: "",
                   duration: 200, isPlaying: isPlaying, position: 30, positionDate: reported)
    }

    @Test func advancesWhilePlaying() {
        #expect(track(isPlaying: true).position(at: reported.addingTimeInterval(10)) == 40)
    }

    @Test func holdsWhilePaused() {
        #expect(track(isPlaying: false).position(at: reported.addingTimeInterval(10)) == 30)
    }

    @Test func neverRunsPastTheEnd() {
        #expect(track(isPlaying: true).position(at: reported.addingTimeInterval(1000)) == 200)
    }
}
