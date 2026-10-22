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
        GeometryReader { geometry in
            let showsCaptions = geometry.size.width >= 64
            VStack(spacing: 10) {
                Text(value.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "–")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.inkSecondary)
                    .contentTransition(.numericText(value: value ?? 0))

                track
                    .frame(maxWidth: min(geometry.size.width, 64))

                Button(action: iconTapped) {
                    Image(systemName: symbol)
                        .font(.system(size: 17))
                        .foregroundStyle(value == nil ? .inkTertiary : .ink)
                        .frame(width: 44, height: 30)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .disabled(control == .brightness || value == nil)

                if showsCaptions {
                    Text(caption)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.inkTertiary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Unavailable controls keep their shape, just empty and quiet, so the page never reflows.
    private var track: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width / 2.4, 26)
            ZStack(alignment: .bottom) {
                Rectangle().fill(.white.opacity(value == nil ? 0.04 : 0.1))
                Rectangle()
                    .fill(.ink)
                    .frame(height: geometry.size.height * (value ?? 0))
                    // Under a finger the fill tracks exactly; changes from the Mac ease in.
                    .animation(dragStart == nil ? .smooth(duration: 0.25) : nil, value: value)
            }
            .clipShape(.rect(cornerRadius: radius, style: .continuous))
            .glassEffect(.regular, in: .rect(cornerRadius: radius, style: .continuous))
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard let value else { return }
                        let start = dragStart ?? value
                        dragStart = start
                        set(min(max(start - drag.translation.height / geometry.size.height, 0), 1))
                    }
                    .onEnded { _ in dragStart = nil },
                isEnabled: value != nil
            )
            .sensoryFeedback(.selection, trigger: ((value ?? 0) * 10).rounded())
        }
        .accessibilityElement()
        .accessibilityLabel(control == .brightness ? "Brightness" : "Volume")
        .accessibilityValue(value.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? String(localized: "Unavailable"))
        .accessibilityAdjustableAction { direction in
            guard let value else { return }
            set(min(max(value + (direction == .increment ? 0.1 : -0.1), 0), 1))
        }
    }

    private var value: Double? {
        switch control {
        case .brightness: model.controls.brightness
        case .volume: model.controls.volume.map { model.controls.isMuted ? 0 : $0 }
        }
    }

    private var caption: String {
        switch control {
        case .brightness:
            guard model.controls.brightness != nil else { return String(localized: "Unavailable") }
            let name = model.controls.displayName ?? String(localized: "Display")
            // Honest about how a non-Apple display is dimmed.
            return model.controls.isBrightnessSoftware ? String(localized: "\(name)\nSoftware") : name
        case .volume:
            return model.controls.outputName ?? String(localized: "No Output")
        }
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

    private var symbol: String {
        guard let value else { return control == .brightness ? "sun.max" : "speaker.slash" }
        switch control {
        case .brightness:
            return value < 0.35 ? "sun.min" : "sun.max"
        case .volume:
            if value == 0 { return "speaker.slash.fill" }
            return value < 0.34 ? "speaker.wave.1.fill" : value < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
        }
    }
}
