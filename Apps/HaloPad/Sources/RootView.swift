import SwiftUI
import HaloCore

struct RootView: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            StatusStrip()
            ModeView(mode: model.mode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            ModePicker()
        }
        .background(Color.black)
    }
}

struct StatusStrip: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        HStack(spacing: 24) {
            Label(model.connectedMacName ?? "Not connected", systemImage: "laptopcomputer")
            Spacer()
            Text("CPU \(model.metrics.cpu, format: .percent.precision(.fractionLength(0)))")
            Text("RAM \(model.metrics.memory, format: .percent.precision(.fractionLength(0)))")
            Text(Int64(model.metrics.freeStorageBytes), format: .byteCount(style: .file))
        }
        .font(.footnote.monospacedDigit())
        .foregroundStyle(.secondary)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
}

struct ModePicker: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        HStack(spacing: 32) {
            ForEach(Mode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.6)) { model.select(mode) }
                } label: {
                    Image(systemName: mode.systemImage)
                        .font(.title2)
                        .foregroundStyle(model.mode == mode ? .primary : .tertiary)
                }
                .accessibilityLabel(mode.title)
            }
        }
        .padding(.vertical, 20)
    }
}

struct ModeView: View {
    let mode: Mode

    var body: some View {
        switch mode {
        case .zen: ZenView()
        default: PlaceholderModeView(mode: mode)
        }
    }
}

struct ZenView: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 8) {
                Text(context.date, format: .dateTime.hour().minute())
                    .font(.system(size: 160, weight: .thin, design: .rounded))
                Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(Color(red: 1.0, green: 0.92, blue: 0.82))
        }
    }
}

struct PlaceholderModeView: View {
    let mode: Mode

    var body: some View {
        ContentUnavailableView(mode.title, systemImage: mode.systemImage, description: Text("Coming soon"))
    }
}

#Preview {
    RootView().environment(PadModel())
}
