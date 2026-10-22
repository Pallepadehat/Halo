import SwiftUI

/// Halo's visual language: white type in a few weights of ink over a living, blurred backdrop,
/// with Liquid Glass reserved for what you touch.
extension ShapeStyle where Self == Color {
    static var ink: Color { .white.opacity(0.96) }
    static var inkSecondary: Color { .white.opacity(0.62) }
    static var inkTertiary: Color { .white.opacity(0.38) }
    static var inkHairline: Color { .white.opacity(0.1) }

    /// Reserved for things that need you. Always paired with an icon and words.
    static var attention: Color { Color(red: 1.0, green: 0.68, blue: 0.32) }
    /// Work in progress.
    static var progress: Color { Color(red: 0.42, green: 0.86, blue: 0.52) }
}

extension Font {
    /// Hero numbers and the clock: SF at its thinnest, with digits that don't jitter.
    static func hero(_ size: CGFloat) -> Font {
        .system(size: size, weight: .thin).monospacedDigit()
    }

    /// Small spaced capitals, e.g. "IN FOCUS" or "MUSIC · MAC".
    static let eyebrow = Font.system(size: 10, weight: .semibold)
}

extension View {
    /// The spaced small-caps treatment for `Font.eyebrow` labels.
    func eyebrowStyle() -> some View {
        font(.eyebrow).tracking(1.6).textCase(.uppercase)
    }
}

extension Animation {
    /// "Quiet by default": slow, eased transitions.
    static let halo = Animation.smooth(duration: 0.6)
}
