import HaloDashboard
import SwiftUI

/// Lays out one page's widgets on the grid and, in edit mode, lets them be moved, resized
/// and removed. Long-press anywhere empty to start editing.
struct PageGridView: View {
    @Environment(DashboardStore.self) private var store
    let page: DashboardPage

    /// Where the widget being dragged or resized would land.
    @State private var preview: (id: DashboardWidget.ID, frame: GridFrame)?

    var body: some View {
        GeometryReader { proxy in
            let geometry = GridGeometry(bounds: proxy.size)
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(.rect)
                    .onLongPressGesture(minimumDuration: 0.5) { store.isEditing = true }
                    .sensoryFeedback(.impact(weight: .medium), trigger: store.isEditing) { _, isEditing in isEditing }

                if store.isEditing, let preview {
                    let isValid = page.isAvailable(preview.frame, ignoring: preview.id)
                    let rect = geometry.rect(for: preview.frame)
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill((isValid ? Color.white : Color.red).opacity(0.1))
                        .strokeBorder((isValid ? Color.white : Color.red).opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)
                        .animation(.spring(duration: 0.25), value: preview.frame)
                }

                ForEach(page.widgets) { widget in
                    let rect = geometry.rect(for: widget.frame)
                    WidgetContainer(widget: widget, rect: rect, geometry: geometry) { frame in
                        preview = frame.map { (widget.id, $0) }
                    }
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.15), value: page.widgets)
        }
    }
}

/// One widget on the grid, plus its edit-mode chrome and gestures.
private struct WidgetContainer: View {
    @Environment(DashboardStore.self) private var store
    let widget: DashboardWidget
    let rect: CGRect
    let geometry: GridGeometry
    /// Reports where the widget would land while it's being moved or resized.
    let onPreview: (GridFrame?) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 26, style: .continuous) }

    var body: some View {
        WidgetView(kind: widget.kind)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(!store.isEditing)
            .background {
                if store.isEditing {
                    shape.fill(.white.opacity(0.05)).strokeBorder(.white.opacity(0.22), lineWidth: 1)
                }
            }
            .overlay(alignment: .topLeading) {
                if store.isEditing {
                    RemoveButton { store.remove(widget.id) }
                        .offset(x: -10, y: -10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if store.isEditing {
                    ResizeHandle()
                        .offset(x: 6, y: 6)
                        .gesture(resize)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .modifier(Wiggle(isActive: store.isEditing && !isDragging, seed: widget.id.hashValue))
            .scaleEffect(isDragging ? 1.04 : 1)
            .shadow(color: .black.opacity(isDragging ? 0.35 : 0), radius: 24, y: 12)
            .offset(dragOffset)
            .zIndex(isDragging ? 1 : 0)
            .gesture(move, isEnabled: store.isEditing)
            .animation(.spring(duration: 0.3), value: isDragging)
            .accessibilityElement(children: store.isEditing ? .ignore : .contain)
            .accessibilityLabel(widget.kind.title)
            .accessibilityActions {
                if store.isEditing {
                    Button("Remove \(widget.kind.title)") { store.remove(widget.id) }
                }
            }
    }

    private var move: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { drag in
                isDragging = true
                dragOffset = drag.translation
                let corner = CGPoint(x: rect.minX + drag.translation.width, y: rect.minY + drag.translation.height)
                onPreview(GridFrame(origin: geometry.nearestOrigin(to: corner, for: widget.frame.size), size: widget.frame.size))
            }
            .onEnded { drag in
                let corner = CGPoint(x: rect.minX + drag.translation.width, y: rect.minY + drag.translation.height)
                store.move(widget.id, to: geometry.nearestOrigin(to: corner, for: widget.frame.size))
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    dragOffset = .zero
                    isDragging = false
                }
                onPreview(nil)
            }
    }

    private var resize: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { drag in
                onPreview(GridFrame(origin: widget.frame.origin, size: targetSize(for: drag.translation)))
            }
            .onEnded { drag in
                store.resize(widget.id, to: targetSize(for: drag.translation))
                onPreview(nil)
            }
    }

    private func targetSize(for translation: CGSize) -> GridSize {
        let corner = CGPoint(x: rect.maxX + translation.width, y: rect.maxY + translation.height)
        let size = geometry.nearestSize(reaching: corner, from: widget.frame.origin)
        let range = widget.kind.sizeRange
        return GridSize(
            width: min(max(size.width, range.lowerBound.width), range.upperBound.width, Grid.columns - widget.frame.x),
            height: min(max(size.height, range.lowerBound.height), range.upperBound.height, Grid.rows - widget.frame.y)
        )
    }
}

/// The Home Screen jiggle: a continuous, tiny rotation, out of phase per widget so the page
/// feels alive rather than mechanical. Time-driven, so it never stalls or snaps, and the
/// widget's own view keeps its identity when editing starts and stops.
private struct Wiggle: ViewModifier {
    let isActive: Bool
    let seed: Int

    /// About three wobbles a second, a little under a degree each way, as on the Home Screen.
    private static let frequency = 3.1
    private static let amplitude = 0.75

    func body(content: Content) -> some View {
        TimelineView(.animation(paused: !isActive)) { context in
            let phase = Double(abs(seed) % 997) / 997 * 2 * .pi
            let speed = Self.frequency * (0.92 + Double(abs(seed) % 7) * 0.025)
            let angle = sin(context.date.timeIntervalSinceReferenceDate * 2 * .pi * speed + phase)
            content
                .rotationEffect(.degrees(isActive ? angle * Self.amplitude : 0))
                .animation(.easeOut(duration: 0.2), value: isActive)
        }
    }
}

private struct RemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.ink)
                .frame(width: 28, height: 28)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove Widget")
    }
}

private struct ResizeHandle: View {
    var body: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.ink)
            .frame(width: 28, height: 28)
            .glassEffect(.regular.interactive(), in: .circle)
            .contentShape(.circle.inset(by: -10))
            .accessibilityLabel("Resize Widget")
    }
}
