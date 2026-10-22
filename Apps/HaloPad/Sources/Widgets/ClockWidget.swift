import HaloCore
import SwiftUI

/// The time in SF at its thinnest, the date above, and what's next on the calendar below.
struct ClockWidget: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.everyMinute) { context in
                VStack(spacing: geometry.size.height * 0.04) {
                    Text(context.date, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.system(size: max(13, geometry.size.height * 0.07), weight: .regular))
                        .foregroundStyle(.inkSecondary)

                    Text(context.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                        .font(.hero(min(geometry.size.height * 0.62, geometry.size.width * 0.3)))
                        .foregroundStyle(.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                        .contentTransition(.numericText())

                    if let event = model.upNext, geometry.size.height > 220 {
                        UpNextPill(event: event, now: context.date)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.halo, value: context.date)
            }
        }
    }
}

private struct UpNextPill: View {
    let event: UpcomingEvent
    let now: Date

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(Color(hex: event.calendarColor) ?? .inkSecondary)
                .frame(width: 3, height: 16)
            Text(event.title)
                .foregroundStyle(.ink)
                .lineLimit(1)
            Text(timing)
                .foregroundStyle(.inkSecondary)
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: .capsule)
    }

    private var timing: String {
        if event.isAllDay { return String(localized: "Today") }
        if event.start <= now { return String(localized: "Now") }
        let minutes = Int(event.start.timeIntervalSince(now) / 60)
        if minutes < 60 { return String(localized: "in \(max(minutes, 1)) min") }
        return event.start.formatted(date: .omitted, time: .shortened)
    }
}

extension Color {
    /// `#RRGGBB`.
    init?(hex: String?) {
        guard let hex, hex.hasPrefix("#"), hex.count == 7, let value = Int(hex.dropFirst(), radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
