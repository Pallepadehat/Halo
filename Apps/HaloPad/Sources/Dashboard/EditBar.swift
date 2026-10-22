import HaloDashboard
import SwiftUI

/// Replaces the status bar while editing: add widgets, name or delete the page, and finish.
struct EditBar: View {
    @Environment(DashboardStore.self) private var store
    @State private var isConfirmingDelete = false
    @State private var title = ""

    var body: some View {
        HStack(spacing: 14) {
            Button { store.isShowingGallery = true } label: {
                Label("Add Widget", systemImage: "plus")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)

            Spacer()

            TextField("Page Name", text: $title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.ink)
                .frame(width: 260)
                .padding(.vertical, 9)
                .glassEffect(.regular, in: .capsule)
                .onSubmit { store.renameCurrentPage(title) }

            Spacer()

            Button(role: .destructive) { isConfirmingDelete = true } label: {
                Label("Delete Page", systemImage: "trash")
                    .labelStyle(.iconOnly)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(store.pages.count < 2)

            Button("Done") {
                store.renameCurrentPage(title)
                store.isEditing = false
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
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
