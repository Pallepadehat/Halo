import Foundation
import Testing
@testable import HaloCore

@Suite struct UpcomingEventTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Copenhagen")!
        return calendar
    }()

    /// Thursday 22 October 2026 at the given time, in Copenhagen.
    func date(day: Int = 22, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    func timed(_ start: Date, title: String = "Event") -> UpcomingEvent {
        UpcomingEvent(title: title, start: start, end: start.addingTimeInterval(1800), isAllDay: false, location: nil, calendarColor: nil)
    }

    func allDay(day: Int, title: String = "Holiday") -> UpcomingEvent {
        UpcomingEvent(title: title, start: date(day: day, 0), end: date(day: day + 1, 0), isAllDay: true, location: nil, calendarColor: nil)
    }

    @Test func anAllDayEventTomorrowIsTomorrowNotToday() {
        #expect(allDay(day: 23).timing(at: date(20), calendar: calendar) == .allDayTomorrow)
    }

    @Test func anAllDayEventUnderwayIsToday() {
        #expect(allDay(day: 22).timing(at: date(20), calendar: calendar) == .allDayToday)
    }

    @Test func aMorningEventTomorrowSaysTomorrow() {
        let start = date(day: 23, 9)
        #expect(timed(start).timing(at: date(20), calendar: calendar) == .tomorrow(start))
    }

    @Test func laterTodayGivesItsTime() {
        let start = date(18)
        #expect(timed(start).timing(at: date(15), calendar: calendar) == .laterToday(start))
    }

    @Test func soonCountsDownEvenPastMidnight() {
        #expect(timed(date(day: 23, 0, 20)).timing(at: date(23, 50), calendar: calendar) == .inMinutes(30))
    }

    @Test func underwayIsNow() {
        #expect(timed(date(14, 50)).timing(at: date(15), calendar: calendar) == .now)
    }

    @Test func todayComesBeforeTomorrowsTimedEvents() {
        let next = UpcomingEvent.mostRelevant([timed(date(day: 23, 9), title: "Standup"), allDay(day: 22, title: "Birthday")],
                                              at: date(20), calendar: calendar)
        #expect(next?.title == "Birthday")
    }

    @Test func withinADayTimedEventsWin() {
        let next = UpcomingEvent.mostRelevant([allDay(day: 23), timed(date(day: 23, 9), title: "Standup")],
                                              at: date(20), calendar: calendar)
        #expect(next?.title == "Standup")
    }
}
