#if os(macOS)
@preconcurrency import EventKit
import AppKit
import HaloCore

/// The next event on any calendar, for the clock widget. Asks for calendar access once.
@MainActor
public final class UpNext {
    /// How far ahead counts as "next".
    static let horizon: TimeInterval = 18 * 60 * 60

    private let store = EKEventStore()
    private var isAuthorized = false

    public init() {}

    public func requestAccess() async {
        isAuthorized = (try? await store.requestFullAccessToEvents()) ?? false
    }

    /// Called whenever calendars change, so the clock updates without polling.
    public func onChange(_ handler: @escaping @MainActor () -> Void) {
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
    }

    public func next(after date: Date = .now) -> UpcomingEvent? {
        guard isAuthorized else { return nil }
        let predicate = store.predicateForEvents(withStart: date, end: date.addingTimeInterval(Self.horizon), calendars: nil)
        let events = store.events(matching: predicate)
            .filter { $0.endDate > date && $0.status != .canceled }
            .map { event in
                UpcomingEvent(
                    title: event.title ?? String(localized: "Untitled"),
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    location: event.location,
                    calendarColor: event.calendar.flatMap { NSColor(cgColor: $0.cgColor)?.hexString }
                )
            }
        return Self.mostRelevant(events)
    }

    /// Timed events beat all-day ones; among those, the soonest.
    nonisolated static func mostRelevant(_ events: [UpcomingEvent]) -> UpcomingEvent? {
        events.min { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay { return !lhs.isAllDay }
            return lhs.start < rhs.start
        }
    }
}

private extension NSColor {
    var hexString: String? {
        guard let rgb = usingColorSpace(.sRGB) else { return nil }
        let components = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent].map { Int(($0 * 255).rounded()) }
        return "#" + components.map { String(format: "%02X", $0) }.joined()
    }
}
#endif
