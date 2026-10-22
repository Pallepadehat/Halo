import HaloDashboard
import SwiftUI

/// The whole iPad: backdrop, status bar, the person's pages, the page indicator and the Dock.
struct DashboardView: View {
    @Environment(DashboardStore.self) private var store
    @Environment(Ambience.self) private var ambience

    var body: some View {
        @Bindable var store = store
        ZStack {
            Backdrop()

            GeometryReader { screen in
                VStack(spacing: 0) {
                    Group {
                        if store.isEditing {
                            EditBar().transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            StatusBar().transition(.opacity)
                        }
                    }
                    .frame(height: 56)

                    Pager(pages: store.pages, selection: $store.currentPageID, isEnabled: !store.isWidgetCapturingTouches) { page in
                        PageGridView(page: page)
                            .padding(.horizontal, 32)
                            .padding(.top, 8)
                    }

                    PageIndicator()
                        .frame(height: 36)

                    DockBar(availableWidth: screen.size.width - 64)
                        .padding(.bottom, 20)
                }
            }
            .offset(ambience.pixelShift)
            .animation(.easeInOut(duration: 8), value: ambience.pixelShift)

            // Night: dim everything but leave it legible and touchable.
            Color.black
                .opacity(ambience.isNight ? 0.5 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 2), value: ambience.isNight)
        }
        .animation(.halo, value: store.isEditing)
        .animation(.smooth(duration: 0.5), value: store.currentPageID)
        .task { await ambience.run() }
    }
}
