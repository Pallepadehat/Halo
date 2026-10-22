import SwiftUI

/// Halo's palette: warm, low-contrast, nothing that shouts unless it must.
extension ShapeStyle where Self == Color {
    /// The warm off-white used for hero text.
    static var haloInk: Color { Color(red: 1.0, green: 0.92, blue: 0.82) }
    /// Cards and raised surfaces on the black background.
    static var haloSurface: Color { Color(white: 1, opacity: 0.06) }
    /// Reserved for things that need you.
    static var haloAttention: Color { Color(red: 1.0, green: 0.67, blue: 0.35) }
}

extension Animation {
    /// "Quiet by default": slow, eased transitions.
    static let halo = Animation.easeInOut(duration: 0.6)
}
