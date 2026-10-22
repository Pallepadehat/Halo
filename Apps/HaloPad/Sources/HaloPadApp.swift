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
                #if DEBUG
                .modifier(DebugFrame.fromArguments)
                #endif
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
        if let flag = arguments.firstIndex(of: "-HaloDemoPairing") {
            let step = arguments.dropFirst(flag + 1).first ?? "searching"
            return (PadModel(link: .demoPairing(step)), DashboardStore(file: nil, fallback: .empty))
        }
        if let flag = arguments.firstIndex(of: "-HaloDemo") {
            let page = arguments.dropFirst(flag + 1).first.flatMap(Int.init) ?? 0
            let store = DashboardStore(file: nil, fallback: arguments.contains("-HaloDemoEmpty") ? .empty : .showcase)
            store.show(pageAt: page)
            store.isEditing = arguments.contains("-HaloDemoEditing") || arguments.contains("-HaloDemoGallery")
            store.isShowingGallery = arguments.contains("-HaloDemoGallery")
            return (DemoData.model(), store)
        }
        #endif
        MacLink.forgetPairingsFromAnEarlierInstall()
        return (PadModel(link: MacLink(identity: .local(named: UIDevice.current.name))), DashboardStore())
    }
}

struct RootView: View {
    @Environment(MacLink.self) private var link

    var body: some View {
        Group {
            if link.needsPairing {
                PairingView()
            } else {
                DashboardView()
            }
        }
        .animation(.halo, value: link.needsPairing)
    }
}

#if DEBUG
/// `-HaloFrame 1210x834` lays the app out at an exact size, rotated and scaled to fit the
/// screen, so landscape layouts can be checked on a simulator stuck in portrait.
private struct DebugFrame: ViewModifier {
    let size: CGSize?

    static var fromArguments: DebugFrame {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-HaloFrame"), arguments.indices.contains(flag + 1) else { return DebugFrame(size: nil) }
        let parts = arguments[flag + 1].split(separator: "x").compactMap { Double($0) }
        return DebugFrame(size: parts.count == 2 ? CGSize(width: parts[0], height: parts[1]) : nil)
    }

    func body(content: Content) -> some View {
        if let size {
            GeometryReader { screen in
                let scale = min(screen.size.width / size.height, screen.size.height / size.width)
                content
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .rotationEffect(.degrees(90))
                    .scaleEffect(scale)
                    .frame(width: screen.size.width, height: screen.size.height)
            }
            .ignoresSafeArea()
        } else {
            content
        }
    }
}
#endif
