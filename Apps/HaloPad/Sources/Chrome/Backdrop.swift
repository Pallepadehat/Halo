import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

/// The living background behind every page: the album artwork while music plays, otherwise
/// the Mac's own wallpaper, both blurred into colour. Crossfades whenever the source changes.
struct Backdrop: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        ZStack {
            WarmGradient()
            if let source {
                BlurredLayer(source: source)
                    .id(source.id)
                    .transition(.opacity)
            }
            // Keeps white text readable on any picture without flattening its colour.
            LinearGradient(
                colors: [.black.opacity(0.12), .black.opacity(0.28), .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .animation(.easeInOut(duration: 1.4), value: source?.id)
        .ignoresSafeArea()
    }

    private var source: BackdropSource? {
        if let nowPlaying = model.nowPlaying, nowPlaying.isPlaying, let artwork = model.nowPlayingArtwork {
            return BackdropSource(id: "artwork:\(nowPlaying.trackID)", image: artwork, drifts: true)
        }
        if let wallpaper = model.wallpaper {
            return BackdropSource(id: "wallpaper:\(ObjectIdentifier(wallpaper).hashValue)", image: wallpaper, drifts: false)
        }
        return nil
    }
}

struct BackdropSource: Equatable {
    let id: String
    let image: UIImage
    /// Artwork breathes slowly, like Apple Music's full-screen player; wallpaper stays still.
    let drifts: Bool

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

private struct BlurredLayer: View {
    let source: BackdropSource
    @State private var blurred: UIImage?

    var body: some View {
        GeometryReader { geometry in
            if let blurred {
                TimelineView(.animation(minimumInterval: 1 / 20, paused: !source.drifts)) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate / 24
                    Image(uiImage: blurred)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(source.drifts ? 1.35 + 0.05 * sin(phase) : 1.15)
                        .rotationEffect(.degrees(source.drifts ? 6 * sin(phase * 0.7) : 0))
                        .offset(x: source.drifts ? 30 * cos(phase * 0.9) : 0, y: source.drifts ? 20 * sin(phase * 1.1) : 0)
                        .saturation(1.25)
                }
                .clipped()
            }
        }
        .task(id: source.id) {
            blurred = await BackdropBlur.blurred(source.image)
        }
    }
}

/// Blurs once, off the main actor, at a small size. The result is scaled up for display, so
/// the per-frame drift costs a texture transform rather than a live blur.
enum BackdropBlur {
    @concurrent
    static func blurred(_ image: UIImage) async -> UIImage? {
        guard let input = CIImage(image: image) else { return nil }
        let scale = 320 / max(input.extent.width, input.extent.height)
        let small = input.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = small.clampedToExtent()
        blur.radius = 24
        guard let output = blur.outputImage?.cropped(to: small.extent),
              let cgImage = CIContext().createCGImage(output, from: small.extent)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// Shown before the Mac has sent a picture: the warm amber of a desk lamp.
struct WarmGradient: View {
    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.45, 0.4], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                Color(red: 0.30, green: 0.14, blue: 0.08), Color(red: 0.42, green: 0.20, blue: 0.10), Color(red: 0.28, green: 0.12, blue: 0.07),
                Color(red: 0.45, green: 0.24, blue: 0.12), Color(red: 0.62, green: 0.36, blue: 0.18), Color(red: 0.38, green: 0.18, blue: 0.09),
                Color(red: 0.18, green: 0.08, blue: 0.05), Color(red: 0.26, green: 0.12, blue: 0.07), Color(red: 0.16, green: 0.07, blue: 0.05),
            ]
        )
    }
}
