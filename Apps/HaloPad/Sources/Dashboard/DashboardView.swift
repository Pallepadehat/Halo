import HaloDashboard
import SwiftUI

/// The whole iPad: backdrop, status bar, the person's pages, the page indicator and the Dock.
struct DashboardView: View {
    static let barHeight: CGFloat = 52

    @Environment(DashboardStore.self) private var store
    @Environment(Ambience.self) private var ambience
    /// The chrome settles in after the page, so arriving feels like one calm movement:
    /// the hello starts writing, then the status bar and the Dock ease in beneath it.
    @State private var hasArrived = false

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
                    .frame(height: DashboardView.barHeight)
                    // Room above the bar, so its controls never crowd the iPad's edge.
                    .padding(.top, 16)
                    .opacity(hasArrived ? 1 : 0)
                    .animation(.smooth(duration: 1.2).delay(0.5), value: hasArrived)

                    if store.isEmpty, !store.isEditing {
                        HelloView()
                            .transition(.opacity)
                    } else {
                        Pager(pages: store.pages, selection: $store.currentPageID, isEnabled: !store.isWidgetCapturingTouches) { page in
                            PageGridView(page: page)
                                .padding(.horizontal, 32)
                                .padding(.top, 8)
                        }
                        .transition(.opacity)
                    }

                    PageIndicator()
                        .frame(height: 36)

                    DockBar(availableWidth: screen.size.width - 64)
                        .padding(.bottom, 20)
                        .opacity(hasArrived ? 1 : 0)
                        .offset(y: hasArrived ? 0 : 40)
                        .animation(.smooth(duration: 1.4).delay(1.0), value: hasArrived)
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
        .sheet(isPresented: $store.isShowingGallery) { WidgetGallery() }
        .sheet(item: configuringWidget) { widget in WidgetSettings(widget: widget) }
        .animation(.halo, value: store.isEditing)
        .animation(.halo, value: store.isEmpty)
        .animation(.smooth(duration: 0.5), value: store.currentPageID)
        .onAppear { hasArrived = true }
        .task { await ambience.run() }
    }

    private var configuringWidget: Binding<DashboardWidget?> {
        Binding {
            store.configuringWidgetID.flatMap(store.widget)
        } set: { widget in
            store.configuringWidgetID = widget?.id
        }
    }
}
