import HaloCore
import SwiftUI

/// The Mac's Dock, pinned beneath every page in a Liquid Glass tray. Pages slide behind it;
/// it never moves. Tap an app to open it on the Mac.
struct DockBar: View {
    @Environment(PadModel.self) private var model
    @Environment(DashboardStore.self) private var store

    static let iconSide: CGFloat = 64

    var body: some View {
        if !model.launcher.isEmpty {
            HStack(spacing: 18) {
                ForEach(Array(model.launcher.enumerated()), id: \.element.id) { index, item in
                    AppButton(item: item, icon: model.icons[item.id], side: Self.iconSide) { model.launch(item) }
                    // Finder stands apart, as it does in the Mac's own Dock.
                    if index == 0, model.launcher.count > 1 {
                        Capsule().fill(.inkTertiary).frame(width: 1, height: Self.iconSide * 0.55)
                    }
                }
            }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 30, style: .continuous))
            .disabled(store.isEditing)
            .opacity(store.isEditing ? 0.6 : 1)
            .transition(.move(edge: .bottom).combined(with: .opacity))
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
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            .keyframeAnimator(initialValue: 0.0, trigger: launches) { content, lift in
                content.offset(y: -lift)
            } keyframes: { _ in
                // The Dock's launch bounce, once.
                SpringKeyframe(side * 0.3, duration: 0.18)
                SpringKeyframe(0, duration: 0.34)
            }
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel(item.name)
        .sensoryFeedback(.impact(weight: .light), trigger: launches)
    }
}
