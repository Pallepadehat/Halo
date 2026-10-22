import HaloCore
import SwiftUI

/// One-tap actions: the built-ins, every Shortcut on the Mac, and any scripts.
struct DeckWidget: View {
    @Environment(PadModel.self) private var model
    /// The person's chosen actions, in their order; `nil` shows everything.
    var selection: [String]?

    var body: some View {
        let actions = shownActions
        if actions.isEmpty {
            WidgetUnavailable(symbol: "square.grid.3x2", message: "Your Shortcuts and actions appear here.")
        } else {
            GeometryReader { geometry in
                let layout = DeckLayout(size: geometry.size, count: actions.count)
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DeckLayout.spacing), count: layout.columns),
                              spacing: DeckLayout.spacing) {
                        ForEach(actions) { action in
                            DeckButton(action: action, height: layout.buttonHeight) { model.run(action) }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollDisabled(!layout.overflows)
                .scrollEdgeEffectStyle(.soft, for: .vertical)
            }
        }
    }
}

extension DeckWidget {
    /// Chosen actions that still exist on the Mac, in the chosen order.
    var shownActions: [DeckAction] {
        guard let selection else { return model.deck }
        let available = Dictionary(model.deck.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return selection.compactMap { available[$0] }
    }
}

/// Fits whole rows of buttons to the tile, so nothing is ever cut off mid-button; anything
/// beyond what fits scrolls.
private struct DeckLayout {
    static let spacing: CGFloat = 12
    static let minimumButton = CGSize(width: 88, height: 68)
    static let maximumButtonHeight: CGFloat = 104

    let columns: Int
    let buttonHeight: CGFloat
    let overflows: Bool

    init(size: CGSize, count: Int) {
        columns = max(1, Int((size.width + Self.spacing) / (Self.minimumButton.width + Self.spacing)))
        let visibleRows = max(1, Int((size.height + Self.spacing) / (Self.minimumButton.height + Self.spacing)))
        let neededRows = Int((Double(count) / Double(columns)).rounded(.up))
        let rows = min(visibleRows, max(neededRows, 1))
        buttonHeight = min((size.height - Self.spacing * CGFloat(rows - 1)) / CGFloat(rows), Self.maximumButtonHeight)
        overflows = neededRows > visibleRows
    }
}

private struct DeckButton: View {
    let action: DeckAction
    let height: CGFloat
    let run: () -> Void

    @State private var runs = 0

    var body: some View {
        Button {
            runs += 1
            run()
        } label: {
            VStack(spacing: height > 84 ? 10 : 6) {
                Image(systemName: action.symbol)
                    .font(.system(size: height > 84 ? 22 : 18, weight: .regular))
                    .symbolEffect(.bounce, value: runs)
                Text(action.title)
                    .font((height > 84 ? Font.caption : .caption2).weight(.medium))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.ink)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .padding(.horizontal, 8)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressScaleStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: runs)
    }
}
