import HaloDashboard
import SwiftUI

/// Replaces the status bar while editing: add widgets, name or delete the page, and finish.
struct EditBar: View {
    @Environment(DashboardStore.self) private var store
    @State private var isConfirmingDelete = false
    @State private var title = ""

    /// Every control in the bar shares one height, so they line up like a toolbar.
    private static let control: CGFloat = 44

    var body: some View {
        HStack(spacing: 12) {
            Button { store.isShowingGallery = true } label: {
                Label("Add Widget", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: Self.control, height: Self.control)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)

            Spacer()

            TextField("Page Name", text: $title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.ink)
                .frame(width: 260, height: Self.control)
                .glassEffect(.regular.interactive(), in: .capsule)
                .onSubmit { store.renameCurrentPage(title) }

            Spacer()

            Button(role: .destructive) { isConfirmingDelete = true } label: {
                Label("Delete Page", systemImage: "trash")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: Self.control, height: Self.control)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(store.pages.count < 2)

            Button {
                store.renameCurrentPage(title)
                store.isEditing = false
            } label: {
                Text("Done")
                    .font(.headline)
                    .padding(.horizontal, 10)
                    .frame(height: Self.control)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, 28)
        .onAppear { title = store.currentPage.title }
        .onChange(of: store.currentPageID) { title = store.currentPage.title }
        .confirmationDialog("Delete “\(store.currentPage.title)”?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Page", role: .destructive, action: store.removeCurrentPage)
        } message: {
            Text("Its widgets are removed with it.")
        }
    }
}
