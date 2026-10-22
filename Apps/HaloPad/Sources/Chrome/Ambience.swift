import Foundation
import Observation

/// Keeps an always-on screen kind to the room and to its own pixels: dims at night on a
/// schedule (or on request), and nudges everything a few points now and then so nothing
/// burns in.
@MainActor
@Observable
final class Ambience {
    /// Night from 22:00 to 07:00.
    static let nightHours = 22..<31
    static let pixelShiftInterval: Duration = .seconds(180)
    static let pixelShiftRange = -3.0...3.0

    /// `nil` follows the schedule; the moon button pins it on or off until the schedule flips.
    var override: Bool?
    private(set) var isScheduledNight = false
    private(set) var pixelShift = CGSize.zero

    var isNight: Bool {
        override ?? isScheduledNight
    }

    func toggleNight() {
        override = !isNight
    }

    func run() async {
        while !Task.isCancelled {
            let wasNight = isScheduledNight
            isScheduledNight = Self.isNight(at: .now)
            if wasNight != isScheduledNight { override = nil }
            pixelShift = CGSize(width: .random(in: Self.pixelShiftRange), height: .random(in: Self.pixelShiftRange))
            try? await Task.sleep(for: Self.pixelShiftInterval)
        }
    }

    static func isNight(at date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return nightHours.contains(hour) || nightHours.contains(hour + 24)
    }
}
