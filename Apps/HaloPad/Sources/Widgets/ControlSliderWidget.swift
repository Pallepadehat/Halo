import SwiftUI

/// A Control Center–style vertical slider for brightness or volume. Dragging moves the value by
/// the distance travelled, never jumping to the finger, exactly like Control Center.
struct ControlSliderWidget: View {
    enum Control {
        case brightness, volume
    }

    @Environment(PadModel.self) private var model
    let control: Control

    @State private var dragStart: Double?

    var body: some View {
        if let value {
            VStack(spacing: 12) {
                Text(value.formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.inkSecondary)
                    .contentTransition(.numericText(value: value))
                slider(value: value)
                Button(action: iconTapped) {
                    Image(systemName: symbol(for: value))
                        .font(.system(size: 17))
                        .foregroundStyle(.ink)
                        .frame(width: 44, height: 32)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .disabled(control == .brightness)
                Text(deviceName ?? "")
                    .font(.system(size: 9))
                    .foregroundStyle(.inkTertiary)
                    .lineLimit(1)
            }
        } else {
            WidgetUnavailable(
                symbol: control == .brightness ? "sun.max" : "speaker.slash",
                message: control == .brightness ? "Brightness works with built-in and Apple displays." : "No output device"
            )
        }
    }

    private func slider(value: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Rectangle().fill(.white.opacity(0.1))
                Rectangle()
                    .fill(.ink)
                    .frame(height: geometry.size.height * value)
            }
            .clipShape(.rect(cornerRadius: min(geometry.size.width / 2.4, 26), style: .continuous))
            .glassEffect(.regular, in: .rect(cornerRadius: min(geometry.size.width / 2.4, 26), style: .continuous))
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let start = dragStart ?? value
                        dragStart = start
                        set(min(max(start - drag.translation.height / geometry.size.height, 0), 1))
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .sensoryFeedback(.selection, trigger: (value * 10).rounded())
        }
        .frame(maxWidth: 64)
        .accessibilityElement()
        .accessibilityLabel(control == .brightness ? "Brightness" : "Volume")
        .accessibilityValue(value.formatted(.percent.precision(.fractionLength(0))))
        .accessibilityAdjustableAction { direction in
            set(min(max(value + (direction == .increment ? 0.1 : -0.1), 0), 1))
        }
    }

    private var value: Double? {
        switch control {
        case .brightness: model.controls.brightness
        case .volume: model.controls.volume.map { model.controls.isMuted ? 0 : $0 }
        }
    }

    private var deviceName: String? {
        control == .brightness ? model.controls.displayName : model.controls.outputName
    }

    private func set(_ newValue: Double) {
        switch control {
        case .brightness: model.setBrightness(newValue)
        case .volume: model.setVolume(newValue)
        }
    }

    private func iconTapped() {
        if control == .volume { model.toggleMute() }
    }

    private func symbol(for value: Double) -> String {
        switch control {
        case .brightness:
            return value < 0.35 ? "sun.min" : "sun.max"
        case .volume:
            if value == 0 { return "speaker.slash.fill" }
            return value < 0.34 ? "speaker.wave.1.fill" : value < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
        }
    }
}
