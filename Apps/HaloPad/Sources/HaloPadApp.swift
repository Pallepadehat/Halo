import HaloCore
import HaloTransport
import SwiftUI

@main
struct HaloPadApp: App {
    @State private var model = Self.makeModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.link)
                .preferredColorScheme(.dark)
                .persistentSystemOverlays(.hidden)
                .statusBarHidden()
                .task {
                    // Halo is furniture: it stays on while it sits on the desk.
                    UIApplication.shared.isIdleTimerDisabled = true
                    model.start()
                }
        }
    }

    private static func makeModel() -> PadModel {
        #if DEBUG
        // `-HaloDemo [mode]` fills every mode with sample data, no Mac needed.
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-HaloDemo") {
            let mode = arguments.dropFirst(flag + 1).first.flatMap(Mode.init(rawValue:)) ?? .zen
            return .demo(showing: mode)
        }
        #endif
        return PadModel(link: MacLink(identity: .local(named: UIDevice.current.name)))
    }
}
