import HaloCore
import SwiftUI

struct ModePicker: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        HStack(spacing: 40) {
            ForEach(Mode.allCases) { mode in
                Button {
                    model.mode = mode
                } label: {
                    Image(systemName: mode.systemImage)
                        .font(.title2)
                        .foregroundStyle(model.mode == mode ? Color.haloInk : Color.haloInk.opacity(0.35))
                        .overlay(alignment: .topTrailing) {
                            if mode == .agents, model.agents.contains(where: \.needsAttention) {
                                Circle()
                                    .fill(.haloAttention)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 6, y: -4)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.title)
                .accessibilityAddTraits(model.mode == mode ? .isSelected : [])
            }
        }
        .padding(.vertical, 16)
    }
}
