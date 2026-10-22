import HaloCore
import SwiftUI

/// The Mac's Dock on the iPad. Tap an app to open it on the Mac.
struct DockWidget: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.height * 0.82, 88)
            if model.launcher.isEmpty {
                WidgetUnavailable(symbol: "dock.rectangle", message: "Your Mac's Dock appears here.")
            } else {
                HStack(spacing: side * 0.32) {
                    ForEach(Array(model.launcher.enumerated()), id: \.element.id) { index, item in
                        AppButton(item: item, icon: model.icons[item.id], side: side) { model.launch(item) }
                        // Finder stands apart, as it does in the Mac's own Dock.
                        if index == 0, model.launcher.count > 1 {
                            Capsule().fill(.inkTertiary).frame(width: 1.5, height: side * 0.5)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal, side * 0.3)
            }
        }
    }
}

private struct AppButton: View {
    let item: LaunchItem
    let icon: UIImage?
    let side: CGFloat
    let launch: () -> Void

    @State private var launches = 0

    var body: some View {
        Button {
            launches += 1
            launch()
        } label: {
            Group {
                if let icon {
                    Image(uiImage: icon).resizable().interpolation(.high)
                } else {
                    RoundedRectangle(cornerRadius: side * 0.225, style: .continuous)
                        .fill(.white.opacity(0.15))
                        .overlay(Text(item.name.prefix(1)).font(.title2.weight(.medium)).foregroundStyle(.ink))
                }
            }
            .frame(width: side, height: side)
            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
            .keyframeAnimator(initialValue: 0.0, trigger: launches) { content, lift in
                content.offset(y: -lift)
            } keyframes: { _ in
                // The Dock's launch bounce, once.
                SpringKeyframe(side * 0.28, duration: 0.18)
                SpringKeyframe(0, duration: 0.32)
            }
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(item.name)
        .sensoryFeedback(.impact(weight: .light), trigger: launches)
    }
}
