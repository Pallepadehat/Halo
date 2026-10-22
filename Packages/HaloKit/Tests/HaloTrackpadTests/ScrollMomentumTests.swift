import Testing
import HaloProtocol
@testable import HaloTrackpad

@Suite struct ScrollMomentumTests {
    @Test func coastsInTheFlickDirectionAndSlowsToAStop() throws {
        var momentum = try #require(ScrollMomentum(velocity: (x: 0, y: 1200)))
        var steps: [Double] = []
        while let step = momentum.advance(by: 1.0 / 120) { steps.append(step.dy) }

        #expect(steps.count > 30)
        #expect(steps.allSatisfy { $0 > 0 })
        #expect(zip(steps, steps.dropFirst()).allSatisfy { $0 > $1 }, "Each frame moves less than the last")
    }

    @Test func gentleMovementDoesNotCoast() {
        #expect(ScrollMomentum(velocity: (x: 20, y: 60)) == nil)
    }

    /// Two-finger scroll, lifted while still moving fast.
    @Test func aFlickLaunchesMomentum() {
        var interpreter = TrackpadInterpreter()
        var time = 0.0
        for step in 0...6 {
            let y = 100 + Double(step) * 24
            _ = interpreter.update([TouchPoint(id: 0, x: 100, y: y), TouchPoint(id: 1, x: 160, y: y)], at: time)
            time += 1.0 / 120
        }
        _ = interpreter.update([], at: time)
        let momentum = interpreter.takeMomentum()
        #expect((momentum?.velocity.y ?? 0) > 1000)
        #expect(interpreter.takeMomentum() == nil, "Taken once")
    }

    @Test func pausingBeforeLiftingDoesNotCoast() {
        var interpreter = TrackpadInterpreter()
        var time = 0.0
        for step in 0...6 {
            let y = 100 + Double(step) * 24
            _ = interpreter.update([TouchPoint(id: 0, x: 100, y: y), TouchPoint(id: 1, x: 160, y: y)], at: time)
            time += 1.0 / 120
        }
        _ = interpreter.update([], at: time + 0.3)
        #expect(interpreter.takeMomentum() == nil)
    }
}
