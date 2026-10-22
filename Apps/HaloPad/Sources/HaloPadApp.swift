import HaloTransport
import SwiftUI

@main
struct HaloPadApp: App {
    @State private var model = PadModel(link: MacLink(identity: .local(named: UIDevice.current.name)))

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
}
