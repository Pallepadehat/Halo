import SwiftUI

/// The first launch: nothing on the page but a handwritten hello, then an invitation to begin.
/// Hold anywhere to start adding widgets; tap to see it written again.
struct HelloView: View {
    @Environment(DashboardStore.self) private var store
    @State private var progress = 0.0
    @State private var isShowingHint = false

    /// The colours Apple wrote "hello" in, fading in and out at the ends of the stroke.
    private static let ink = LinearGradient(
        colors: [.green, .yellow, .orange, .red, .pink, .purple, .blue],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        VStack(spacing: 8) {
            HelloShape()
                .trim(from: 0, to: progress)
                .stroke(Self.ink, style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
                .shadow(color: .white.opacity(0.25), radius: 18)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 620)
                // The glyph sits in the middle of its square; pull the hint up beneath it.
                .padding(.bottom, -160)

            Label("Hold to add widgets", systemImage: "hand.tap")
                .font(.title3.weight(.medium))
                .foregroundStyle(.inkSecondary)
                .opacity(isShowingHint ? 1 : 0)
                .offset(y: isShowingHint ? 0 : 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .onTapGesture(perform: write)
        .onLongPressGesture(minimumDuration: 0.45) { store.beginAddingWidgets() }
        .sensoryFeedback(.impact(weight: .medium), trigger: store.isShowingGallery) { _, isShowing in isShowing }
        .onAppear(perform: write)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hello. Touch and hold to add widgets.")
        .accessibilityAction(named: "Add Widgets") { store.beginAddingWidgets() }
    }

    private func write() {
        progress = 0
        isShowingHint = false
        withAnimation(.easeInOut(duration: 3.2)) { progress = 1 }
        withAnimation(.smooth(duration: 0.8).delay(2.8)) { isShowingHint = true }
    }
}
