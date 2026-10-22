import HaloDashboard
import SwiftUI

/// Every widget, previewed live. Pick one, swipe through its sizes, add it to this page.
struct WidgetGallery: View {
    @Environment(DashboardStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 18)], spacing: 18) {
                    ForEach(WidgetKind.allCases) { kind in
                        NavigationLink(value: kind) {
                            GalleryCard(kind: kind)
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
                .padding(28)
            }
            .navigationTitle("Widgets")
            .navigationDestination(for: WidgetKind.self) { kind in
                WidgetSizePicker(kind: kind) { dismiss() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", role: .cancel) { dismiss() }
                }
            }
        }
        .presentationSizing(.page)
        .presentationBackground { GalleryBackdrop() }
    }
}

/// A card with the widget running live at its default size, scaled to fit.
private struct GalleryCard: View {
    @Environment(DashboardStore.self) private var store
    let kind: WidgetKind

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LivePreview(kind: kind, family: kind.defaultFamily, pageSize: store.pageSize)
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 4) {
                Label(kind.title, systemImage: kind.symbol)
                    .font(.headline)
                    .foregroundStyle(.ink)
                Text(kind.summary)
                    .font(.subheadline)
                    .foregroundStyle(.inkSecondary)
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 28, style: .continuous))
    }
}

/// Swipe between the sizes a widget comes in, each previewed at its real proportions.
private struct WidgetSizePicker: View {
    @Environment(DashboardStore.self) private var store
    let kind: WidgetKind
    let onAdd: () -> Void

    @State private var family: WidgetFamily?
    @State private var isPageFull = false

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text(kind.title).font(.largeTitle.weight(.semibold)).foregroundStyle(.ink)
                Text(kind.summary).font(.title3).foregroundStyle(.inkSecondary).multilineTextAlignment(.center)
            }
            .padding(.top, 12)

            TabView(selection: $family) {
                ForEach(kind.families) { family in
                    LivePreview(kind: kind, family: family, pageSize: store.pageSize)
                        .padding(.horizontal, 48)
                        .tag(Optional(family))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if kind.families.count > 1 {
                HStack(spacing: 8) {
                    ForEach(kind.families) { option in
                        Button(option.title) { withAnimation(.smooth) { family = option } }
                            .buttonStyle(.glass)
                            .tint(option == selected ? .white : .clear)
                            .fontWeight(option == selected ? .semibold : .regular)
                    }
                }
            }

            Button {
                if store.add(kind, family: selected) { onAdd() } else { isPageFull = true }
            } label: {
                Label("Add Widget", systemImage: "plus")
                    .font(.headline)
                    .frame(minWidth: 220)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .padding(.bottom, 28)
        }
        .onAppear { family = family ?? kind.defaultFamily }
        .alert("No room on this page", isPresented: $isPageFull) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Choose a smaller size, make space by moving or removing a widget, or add a new page.")
        }
    }

    private var selected: WidgetFamily {
        family ?? kind.defaultFamily
    }
}

/// The real widget, laid out at the exact size it would have on the page, then scaled to fit,
/// so what you pick is precisely what you get.
struct LivePreview: View {
    let kind: WidgetKind
    let family: WidgetFamily
    let pageSize: CGSize

    var body: some View {
        let size = GridGeometry(bounds: pageSize).size(of: family)
        GeometryReader { container in
            let scale = min(container.size.width / size.width, container.size.height / size.height, 1)
            WidgetView(kind: kind)
                .frame(width: size.width, height: size.height)
                .padding(12)
                .background(.white.opacity(0.04), in: .rect(cornerRadius: 26, style: .continuous))
                .allowsHitTesting(false)
                .scaleEffect(scale)
                .frame(width: container.size.width, height: container.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.title), \(family.title)")
    }
}

/// The gallery sits over the same living backdrop as the pages, so previews look as they will.
private struct GalleryBackdrop: View {
    var body: some View {
        Backdrop()
            .overlay(.black.opacity(0.25))
    }
}
