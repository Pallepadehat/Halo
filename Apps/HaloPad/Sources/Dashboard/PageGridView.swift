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
            // One container for the page's glass, so it renders together rather than per widget.
            GlassEffectContainer(spacing: geometry.spacing) {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(.rect)
                    .onLongPressGesture(minimumDuration: 0.5) { store.isEditing = true }
                    .sensoryFeedback(.impact(weight: .medium), trigger: store.isEditing) { _, isEditing in isEditing }
                    .onAppear { store.pageSize = proxy.size }
                    .onChange(of: proxy.size) { store.pageSize = proxy.size }

                if store.isEditing, page.widgets.isEmpty {
                    EmptyPageHint()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .transition(.opacity)
                }

                if store.isEditing, let preview {
                    let isValid = page.isAvailable(preview.frame, ignoring: preview.id)
                    let rect = geometry.rect(for: preview.frame)
                    RoundedRectangle(cornerRadius: WidgetCard.cornerRadius, style: .continuous)
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
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.15), value: page.widgets)
            }
        }
    }
}

/// An empty page while editing: one quiet invitation, in place of the widgets to come.
private struct EmptyPageHint: View {
    @Environment(DashboardStore.self) private var store

    var body: some View {
        Button { store.isShowingGallery = true } label: {
            VStack(spacing: 14) {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .medium))
                    .frame(width: 64, height: 64)
                    .glassEffect(.regular.interactive(), in: .circle)
                Text("Add Widgets")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.ink)
                Text("Choose from the gallery, then drag them where you like.")
                    .font(.subheadline)
                    .foregroundStyle(.inkSecondary)
            }
            .foregroundStyle(.ink)
            .multilineTextAlignment(.center)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
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

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: WidgetCard.cornerRadius, style: .continuous) }

    @State private var isConfirmingRemoval = false

    var body: some View {
        WidgetView(widget: widget)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(!store.isEditing)
            .background {
                if store.isEditing {
                    shape.fill(.white.opacity(0.05)).strokeBorder(.white.opacity(0.22), lineWidth: 1)
                }
            }
            // The widget's own tap target comes first, so the corner controls always sit above it.
            .overlay {
                if store.isEditing, widget.kind.isConfigurable {
                    Color.clear
                        .contentShape(.rect)
                        .onTapGesture { store.configuringWidgetID = widget.id }
                        .accessibilityElement()
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("Edit \(widget.kind.title)")
                }
            }
            .overlay(alignment: .topLeading) {
                if store.isEditing {
                    RemoveButton(title: widget.kind.title) { isConfirmingRemoval = true }
                        .offset(x: -12, y: -12)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                        .confirmationDialog("Remove “\(widget.kind.title)”?", isPresented: $isConfirmingRemoval, titleVisibility: .visible) {
                            Button("Remove Widget", role: .destructive, action: remove)
                        } message: {
                            Text("Removing this widget won't change anything on your Mac.")
                        }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if store.isEditing, widget.kind.families.count > 1 {
                    ResizeHandle()
                        .offset(x: 8, y: 8)
                        .gesture(resize)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .contextMenu {
                if store.isEditing {
                    if widget.kind.isConfigurable {
                        Button("Edit Widget", systemImage: "slider.horizontal.3") { store.configuringWidgetID = widget.id }
                    }
                    Button("Remove Widget", systemImage: "minus.circle", role: .destructive, action: remove)
                }
            }
            .scaleEffect(isDragging ? 1.04 : 1)
            .shadow(color: .black.opacity(isDragging ? 0.35 : 0), radius: 24, y: 12)
            .offset(dragOffset)
            .zIndex(isDragging ? 1 : 0)
            .gesture(move, isEnabled: store.isEditing)
            .animation(.spring(duration: 0.3), value: isDragging)
            .sensoryFeedback(.impact(weight: .medium), trigger: isConfirmingRemoval) { _, isConfirming in isConfirming }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(widget.kind.title)
    }

    private func remove() {
        withAnimation(.smooth(duration: 0.35)) { store.remove(widget.id) }
    }

    private var move: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { drag in
                isDragging = true
                dragOffset = drag.translation
                let corner = CGPoint(x: rect.minX + drag.translation.width, y: rect.minY + drag.translation.height)
                onPreview(GridFrame(origin: geometry.nearestOrigin(to: corner, for: widget.family.size), size: widget.family.size))
            }
            .onEnded { drag in
                let corner = CGPoint(x: rect.minX + drag.translation.width, y: rect.minY + drag.translation.height)
                store.move(widget.id, to: geometry.nearestOrigin(to: corner, for: widget.family.size))
                withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                    dragOffset = .zero
                    isDragging = false
                }
                onPreview(nil)
            }
    }

    /// Drags snap between the sizes the widget comes in, like the Home Screen's resize handle.
    private var resize: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { drag in
                let family = targetFamily(for: drag.translation)
                onPreview(GridFrame(origin: widget.origin, size: family.size))
            }
            .onEnded { drag in
                store.resize(widget.id, to: targetFamily(for: drag.translation))
                onPreview(nil)
            }
    }

    private func targetFamily(for translation: CGSize) -> WidgetFamily {
        let corner = CGPoint(x: rect.maxX + translation.width, y: rect.maxY + translation.height)
        return geometry.nearestFamily(reaching: corner, from: widget.origin, among: widget.kind.families) ?? widget.family
    }
}

/// The Home Screen's remove control: a small glass disc with a minus, and a far larger
/// invisible target, so it's easy to hit even with the widget beneath it.
private struct RemoveButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.ink)
                .frame(width: 30, height: 30)
                .glassEffect(.regular, in: .circle)
                .padding(10)
                .contentShape(.circle)
        }
        .buttonStyle(PressScaleStyle())
        .padding(-10)
        .accessibilityLabel("Remove \(title)")
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
