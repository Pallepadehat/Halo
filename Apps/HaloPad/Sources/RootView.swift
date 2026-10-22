import HaloCore
import SwiftUI

struct RootView: View {
    @Environment(PadModel.self) private var model
    @Environment(MacLink.self) private var link

    var body: some View {
        Group {
            if link.status == .unpaired {
                PairingView()
            } else {
                VStack(spacing: 0) {
                    StatusStrip()
                    ModeView(mode: model.mode)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    ModePicker()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .animation(.halo, value: link.status)
        .animation(.halo, value: model.mode)
    }
}

struct ModeView: View {
    let mode: Mode

    var body: some View {
        switch mode {
        case .zen: ZenView()
        case .agents: AgentsView()
        default: PlaceholderModeView(mode: mode)
        }
    }
}

struct PlaceholderModeView: View {
    let mode: Mode

    var body: some View {
        ContentUnavailableView(mode.title, systemImage: mode.systemImage, description: Text("Coming soon"))
    }
}
