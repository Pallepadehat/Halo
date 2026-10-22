import HaloDashboard
import SwiftUI

/// Horizontal paging between dashboard pages. Built on a plain drag rather than a scroll view,
/// so it never delays touches to the widgets inside (a trackpad can't afford that), and can be
/// switched off while a widget owns the touch.
struct Pager<Content: View>: View {
    let pages: [DashboardPage]
    @Binding var selection: DashboardPage.ID
    var isEnabled = true
    @ViewBuilder let content: (DashboardPage) -> Content

    @GestureState private var dragOffset: CGFloat = 0
    /// The page we've come to rest on. Until the slide finishes, the neighbours stay built.
    @State private var settledIndex: Int?

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let index = pages.firstIndex { $0.id == selection } ?? 0
            HStack(spacing: 0) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { position, page in
                    // At rest only the current page is alive; while swiping or sliding, its
                    // neighbours are built too. Everything else costs nothing.
                    let isMoving = dragOffset != 0 || settledIndex != index
                    Group {
                        if position == index || (isMoving && abs(position - index) == 1) { content(page) } else { Color.clear }
                    }
                    .frame(width: width, height: geometry.size.height)
                }
            }
            .offset(x: -CGFloat(index) * width + clamped(dragOffset, at: index))
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 24)
                    .updating($dragOffset) { drag, offset, _ in
                        guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
                        offset = drag.translation.width
                    }
                    .onEnded { drag in
                        let projected = drag.predictedEndTranslation.width
                        guard abs(drag.translation.width) > abs(drag.translation.height) else { return }
                        let step = projected < -width / 3 ? 1 : projected > width / 3 ? -1 : 0
                        let target = min(max(index + step, 0), pages.count - 1)
                        selection = pages[target].id
                    },
                // One page has nowhere to go.
                isEnabled: isEnabled && pages.count > 1
            )
        }
        .clipped()
        .task(id: selection) {
            // Matches the page slide in DashboardView; then let the neighbours go.
            try? await Task.sleep(for: .milliseconds(550))
            settledIndex = pages.firstIndex { $0.id == selection }
        }
    }

    /// Past the first or last page there's nothing to show, so the drag simply stops.
    private func clamped(_ offset: CGFloat, at index: Int) -> CGFloat {
        let isPastEdge = (index == 0 && offset > 0) || (index == pages.count - 1 && offset < 0)
        return isPastEdge ? 0 : offset
    }
}

/// Dots for pages, a dash for the current one. In edit mode, a + adds a page after this one.
struct PageIndicator: View {
    @Environment(DashboardStore.self) private var store

    var body: some View {
        HStack(spacing: 8) {
            // One page needs no indicator, unless editing, where its + adds a second.
            ForEach(store.pages.count > 1 || store.isEditing ? Array(store.pages.enumerated()) : [], id: \.element.id) { index, page in
                Button { store.show(pageAt: index) } label: {
                    Capsule()
                        .fill(page.id == store.currentPageID ? Color.ink : Color.inkTertiary)
                        .frame(width: page.id == store.currentPageID ? 18 : 6, height: page.id == store.currentPageID ? 4 : 6)
                        .frame(height: 20)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(page.title)
            }
            if store.isEditing {
                Button(action: store.addPage) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.ink)
                        .frame(width: 24, height: 24)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add Page")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: store.currentPageID)
    }
}
