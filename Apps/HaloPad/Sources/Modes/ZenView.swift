import SwiftUI

struct ZenView: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 8) {
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.system(size: 160, weight: .thin, design: .rounded))
                    .monospacedDigit()
                Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.haloInk)
        }
    }
}

#Preview {
    ZenView()
        .background(.black)
}
