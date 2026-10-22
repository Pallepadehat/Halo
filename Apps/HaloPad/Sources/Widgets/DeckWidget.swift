import HaloCore
import SwiftUI

/// One-tap actions: the built-ins, every Shortcut on the Mac, and any scripts.
struct DeckWidget: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        if model.deck.isEmpty {
            WidgetUnavailable(symbol: "square.grid.3x2", message: "Your Shortcuts and actions appear here.")
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92, maximum: 140), spacing: 14)], spacing: 14) {
                    ForEach(model.deck) { action in
                        DeckButton(action: action) { model.run(action) }
                    }
                }
                .padding(4)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct DeckButton: View {
    let action: DeckAction
    let run: () -> Void

    @State private var runs = 0

    var body: some View {
        Button {
            runs += 1
            run()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: action.symbol)
                    .font(.system(size: 22, weight: .regular))
                    .symbolEffect(.bounce, value: runs)
                Text(action.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.ink)
            .frame(maxWidth: .infinity, minHeight: 92)
            .padding(.horizontal, 8)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: runs)
    }
}
