import HaloCore
import SwiftUI

/// Music or Spotify on the Mac: artwork, what's playing, and the three buttons that matter.
struct NowPlayingWidget: View {
    @Environment(PadModel.self) private var model

    var body: some View {
        GeometryReader { geometry in
            let isTall = geometry.size.height > 160
            // Too narrow for one row: artwork and title above, controls beneath.
            let isCompact = geometry.size.width < 440
            Group {
                if isCompact {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 14) {
                            Artwork(image: model.nowPlayingArtwork)
                                .frame(width: compactArtwork(in: geometry.size), height: compactArtwork(in: geometry.size))
                            TrackLabel(track: model.nowPlaying)
                        }
                        transport
                            .frame(maxWidth: .infinity)
                        if isTall, let track = model.nowPlaying { Progress(track: track) }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 16) {
                            Artwork(image: model.nowPlayingArtwork)
                                .frame(width: artworkSide(in: geometry.size), height: artworkSide(in: geometry.size))
                            TrackLabel(track: model.nowPlaying)
                            Spacer(minLength: 12)
                            transport
                        }
                        if isTall, let track = model.nowPlaying { Progress(track: track) }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isTall ? .top : .center)
            .padding(.horizontal, 4)
        }
        .animation(.halo, value: model.nowPlaying?.trackID)
    }

    private var transport: some View {
        Transport(isPlaying: model.nowPlaying?.isPlaying == true, isEnabled: model.nowPlaying != nil) { model.perform($0) }
    }

    private func artworkSide(in size: CGSize) -> CGFloat {
        min(size.height > 160 ? size.height * 0.55 : size.height * 0.78, 120)
    }

    private func compactArtwork(in size: CGSize) -> CGFloat {
        min(size.height * 0.36, 72)
    }
}

private struct Artwork: View {
    let image: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.white.opacity(0.08))
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    Image(systemName: "music.note")
                        .font(.title2.weight(.light))
                        .foregroundStyle(.inkTertiary)
                }
            }
            .clipShape(.rect(cornerRadius: 10, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
    }
}

private struct TrackLabel: View {
    let track: NowPlaying?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(track.map { "\($0.source.displayName) · Mac" } ?? String(localized: "Mac"))
                .eyebrowStyle()
                .foregroundStyle(.inkTertiary)
            Text(track?.title ?? String(localized: "Not Playing"))
                .font(.headline.weight(.medium))
                .foregroundStyle(.ink)
            if let artist = track?.artist, !artist.isEmpty {
                Text(artist)
                    .font(.subheadline)
                    .foregroundStyle(.inkSecondary)
            }
        }
        .lineLimit(1)
    }
}

private struct Transport: View {
    let isPlaying: Bool
    let isEnabled: Bool
    let perform: (MediaCommand) -> Void

    var body: some View {
        HStack(spacing: 22) {
            button("backward.end.fill", .previous, size: 19)
            button(isPlaying ? "pause.fill" : "play.fill", .playPause, size: 26)
                .contentTransition(.symbolEffect(.replace))
            button("forward.end.fill", .next, size: 19)
        }
        .foregroundStyle(.ink)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
    }

    private func button(_ symbol: String, _ command: MediaCommand, size: CGFloat) -> some View {
        Button { perform(command) } label: {
            Image(systemName: symbol)
                .font(.system(size: size))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(PressScaleStyle())
    }
}

private struct Progress: View {
    let track: NowPlaying

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let position = track.position(at: context.date) ?? 0
            let duration = max(track.duration ?? 0, 1)
            VStack(spacing: 6) {
                GeometryReader { geometry in
                    Capsule().fill(.white.opacity(0.18))
                        .overlay(alignment: .leading) {
                            Capsule().fill(.ink).frame(width: geometry.size.width * min(position / duration, 1))
                        }
                }
                .frame(height: 4)
                HStack {
                    Text(Duration.seconds(position), format: .time(pattern: .minuteSecond))
                    Spacer()
                    Text("-\(Duration.seconds(max(duration - position, 0)).formatted(.time(pattern: .minuteSecond)))")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.inkTertiary)
            }
        }
    }
}

/// The soft press Apple uses on media and launcher controls.
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}
