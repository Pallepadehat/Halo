import HaloDashboard
import SwiftUI

/// Renders one widget's content. Each widget reads its own size and adapts: more room means
/// more detail, never just bigger type.
struct WidgetView: View {
    let kind: WidgetKind
    var options = WidgetOptions()

    init(widget: DashboardWidget) {
        kind = widget.kind
        options = widget.options
    }

    init(kind: WidgetKind) {
        self.kind = kind
    }

    var body: some View {
        if kind.sitsOnACard {
            content
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassEffect(.clear, in: .rect(cornerRadius: WidgetCard.cornerRadius, style: .continuous))
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
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
        case .trackpad: TrackpadWidget(gestureActions: options.gestureActions)
        case .deck: DeckWidget(selection: options.deckActions)
        }
    }
}

enum WidgetCard {
    static let cornerRadius: CGFloat = 28
}

extension WidgetKind {
    /// Information sits on a clear glass platter, like Home Screen widgets. The clock and sliders
    /// float free, as on the Lock Screen and in Control Center; the trackpad is its own glass.
    var sitsOnACard: Bool {
        switch self {
        case .clock, .brightness, .volume, .trackpad: false
        default: true
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
