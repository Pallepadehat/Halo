import HaloCore
import SwiftUI

/// The time in Liquid Glass, the date above, and what's next on the calendar below.
struct ClockWidget: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.everyMinute) { context in
                VStack(spacing: geometry.size.height * 0.04) {
                    Text(context.date, format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.system(size: max(13, geometry.size.height * 0.07), weight: .regular))
                        .foregroundStyle(.inkSecondary)

                    // Cut from Liquid Glass, like the Lock Screen's clock.
                    GlassText(
                        text: context.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)),
                        size: min(geometry.size.height * 0.62, geometry.size.width * 0.3),
                        weight: .light,
                        // A white tint keeps it readable from across the desk, over any backdrop.
                        glass: .regular.tint(.white.opacity(0.35))
                    )
                    .padding(.vertical, geometry.size.height * 0.04)

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
        switch event.timing(at: now) {
        case .now: String(localized: "Now")
        case .inMinutes(let minutes): String(localized: "in \(minutes) min")
        case .laterToday(let start): start.formatted(date: .omitted, time: .shortened)
        case .allDayToday: String(localized: "Today")
        case .tomorrow(let start): String(localized: "Tomorrow \(start.formatted(date: .omitted, time: .shortened))")
        case .allDayTomorrow: String(localized: "Tomorrow")
        case .later(let start): start.formatted(.dateTime.weekday(.wide).hour().minute())
        case .allDayLater(let start): start.formatted(.dateTime.weekday(.wide))
        }
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
