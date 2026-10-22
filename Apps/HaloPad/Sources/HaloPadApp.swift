import HaloDashboard
import HaloTransport
import SwiftUI

@main
struct HaloPadApp: App {
    @State private var model: PadModel
    @State private var store: DashboardStore
    @State private var ambience = Ambience()

    init() {
        let (model, store) = Self.makeState()
        model.onAgentsNeedYou = { [store] in store.reveal(.agents) }
        _model = State(initialValue: model)
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.link)
                .environment(store)
                .environment(ambience)
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
                .statusBarHidden()
                .task {
                    // Halo is furniture: it stays on while it sits on the desk.
                    UIApplication.shared.isIdleTimerDisabled = true
                    model.start()
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-HaloLandscape") { Self.requestLandscape() }
                    #endif
                }
        }
    }

    #if DEBUG
    /// For screenshots on a simulator that's sitting in portrait.
    private static func requestLandscape() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        scene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
    }
    #endif

    private static func makeState() -> (PadModel, DashboardStore) {
        #if DEBUG
        // `-HaloDemo [page]` fills every widget with sample data, no Mac needed.
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-HaloDemo") {
            let page = arguments.dropFirst(flag + 1).first.flatMap(Int.init) ?? 0
            let store = DashboardStore(file: nil)
            store.show(pageAt: page)
            store.isEditing = arguments.contains("-HaloDemoEditing")
            return (DemoData.model(), store)
        }
        #endif
        return (PadModel(link: MacLink(identity: .local(named: UIDevice.current.name))), DashboardStore())
    }
}

struct RootView: View {
    @Environment(MacLink.self) private var link

    var body: some View {
        Group {
            if link.status == .unpaired {
                PairingView()
            } else {
                DashboardView()
            }
        }
        .animation(.halo, value: link.status == .unpaired)
    }
}
