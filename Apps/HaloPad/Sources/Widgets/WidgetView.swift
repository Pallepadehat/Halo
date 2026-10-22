import HaloDashboard
import SwiftUI

/// Renders one widget's content. Each widget reads its own size and adapts: more room means
/// more detail, never just bigger type.
struct WidgetView: View {
    let kind: WidgetKind

    var body: some View {
        switch kind {
        case .clock: ClockWidget()
        case .nowPlaying: NowPlayingWidget()
        case .brightness: ControlSliderWidget(control: .brightness)
        case .volume: ControlSliderWidget(control: .volume)
        case .cpu: ProcessorWidget()
        case .memory: MemoryWidget()
        case .storage: StorageWidget()
        case .network: NetworkWidget()
        case .agents: AgentsWidget()
        case .trackpad: TrackpadWidget()
        case .dock: DockWidget()
        case .deck: DeckWidget()
        }
    }
}

/// A quiet placeholder for widgets waiting on the Mac.
struct WidgetUnavailable: View {
    let symbol: String
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .light))
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.inkTertiary)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
