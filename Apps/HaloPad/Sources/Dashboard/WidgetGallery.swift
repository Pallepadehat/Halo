import HaloDashboard
import SwiftUI

/// Every widget, with what it does. Tap one to add it to the current page.
struct WidgetGallery: View {
    @Environment(DashboardStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isPageFull = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                    ForEach(WidgetKind.allCases) { kind in
                        Button {
                            if store.add(kind) { dismiss() } else { isPageFull = true }
                        } label: {
                            GalleryCard(kind: kind)
                        }
                        .buttonStyle(PressScaleStyle())
                    }
                }
                .padding(24)
            }
            .navigationTitle("Add Widget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
            .alert("No room on this page", isPresented: $isPageFull) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Make space by resizing or removing a widget, or add a new page.")
            }
        }
        .presentationSizing(.page)
    }
}

private struct GalleryCard: View {
    let kind: WidgetKind

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: kind.symbol)
                .font(.system(size: 22))
                .frame(width: 48, height: 48)
                .glassEffect(.regular.tint(.accentColor.opacity(0.4)), in: .circle)
            Text(kind.title)
                .font(.headline)
            Text(kind.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 24, style: .continuous))
    }
}
