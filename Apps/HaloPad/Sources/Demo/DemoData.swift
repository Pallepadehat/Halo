#if DEBUG
import Foundation
import HaloCore
import HaloProtocol
import HaloTransport
import UIKit

/// Realistic sample data for previews and `-HaloDemo` launches, so every widget can be designed
/// on a real iPad without a Mac attached.
enum DemoData {
    static let mac = DeviceIdentity(id: UUID(), name: "MacBook Pro")

    @MainActor
    static func model() -> PadModel {
        let model = PadModel(link: .demo())
        let track = NowPlaying(source: .music, trackID: "demo", title: "Daylight", artist: "Orbit Sessions", album: "Daylight",
                               duration: 214, isPlaying: true, position: 63)
        let apps = [("com.apple.finder", "Finder"), ("com.apple.Safari", "Safari"), ("com.apple.Music", "Music"),
                    ("com.apple.Notes", "Notes"), ("com.openai.chat", "ChatGPT"), ("com.tinyspeck.slackmacgap", "Slack")]
        let messages: [MacMessage] = [
            .metricsHistory(metricsHistory()),
            .agents(agents()),
            .trackpadAvailability(isAvailable: true),
            .wallpaper(jpeg: duskWallpaper()),
            .launcher(apps.map { LaunchItem(id: $0.0, name: $0.1) }),
            .nowPlaying(track),
            .artwork(trackID: "demo", jpeg: artwork()),
            .controls(SystemControls(volume: 0.56, isMuted: false, outputName: "Studio Display", brightness: 0.78, displayName: "Studio Display")),
            .deck(deck()),
            .upNext(UpcomingEvent(title: "Design review", start: .now.addingTimeInterval(25 * 60), end: .now.addingTimeInterval(55 * 60),
                                  isAllDay: false, location: nil, calendarColor: "#FF9F0A")),
        ] + apps.enumerated().map { index, app in .appIcon(id: app.0, png: icon(index: index)) }
        messages.forEach(model.apply)
        return model
    }

    /// Ten minutes at the helper's cadence: a calm baseline, then a build pegging the CPU.
    static func metricsHistory(endingAt end: Date = .now) -> [SystemMetrics] {
        (0..<300).map { index in
            let t = Double(index)
            let build = index > 270
            return SystemMetrics(
                cpu: build ? 0.82 + 0.06 * sin(t) : 0.18 + 0.06 * sin(t / 9) + 0.04 * sin(t / 2.3),
                memory: 0.62 + 0.03 * sin(t / 40),
                memoryUsedBytes: 22_300_000_000,
                freeStorageBytes: 256_000_000_000,
                totalStorageBytes: 994_000_000_000,
                networkBytesInPerSecond: Int64(1_800_000 + 600_000 * sin(t / 6)),
                networkBytesOutPerSecond: 265_000,
                topCPUProcess: build ? ProcessUsage(name: "Xcode", share: 0.63) : nil,
                timestamp: end.addingTimeInterval(Double(index - 299) * 2)
            )
        }
    }

    static func agents() -> [AgentSession] {
        let codex = AgentSession.id(tool: .codex, nativeID: "demo-1")
        return [
            AgentSession(id: codex, tool: .codex, title: "Build the new website", project: "Website", status: .waitingForApproval,
                         pendingApprovals: [ApprovalRequest(sessionID: codex, toolName: "Bash", summary: "npm run deploy -- --prod")]),
            AgentSession(id: AgentSession.id(tool: .claudeCode, nativeID: "demo-2"), tool: .claudeCode, title: "Explore animations",
                         project: "Halo", status: .running),
            AgentSession(id: AgentSession.id(tool: .cursor, nativeID: "demo-3"), tool: .cursor, title: "Prepare the next release",
                         project: "Orbit", status: .running),
        ]
    }

    static func deck() -> [DeckAction] {
        [
            DeckAction(id: "builtin.playPause", title: "Play/Pause", symbol: "playpause.fill", kind: .builtIn),
            DeckAction(id: "shortcut.Focus", title: "Do Not Disturb", symbol: "moon.fill", kind: .shortcut),
            DeckAction(id: "builtin.lockScreen", title: "Lock Screen", symbol: "lock.fill", kind: .builtIn),
            DeckAction(id: "builtin.screenshot", title: "Screenshot", symbol: "camera.viewfinder", kind: .builtIn),
            DeckAction(id: "builtin.toggleDarkMode", title: "Dark Mode", symbol: "circle.lefthalf.filled", kind: .builtIn),
            DeckAction(id: "script.deploy.sh", title: "Deploy staging", symbol: "terminal.fill", kind: .script),
        ]
    }

    // MARK: - Rendered stand-ins

    /// A slate dusk with a low sun, like a blurred evening wallpaper.
    private static func duskWallpaper() -> Data {
        render(CGSize(width: 640, height: 400)) { context, size in
            gradient(context, [UIColor(red: 0.16, green: 0.24, blue: 0.30, alpha: 1), UIColor(red: 0.09, green: 0.14, blue: 0.20, alpha: 1)], size)
            radial(context, UIColor(red: 0.95, green: 0.72, blue: 0.45, alpha: 0.85), at: CGPoint(x: size.width * 0.52, y: size.height * 0.42), radius: 170)
        }
    }

    private static func artwork() -> Data {
        render(CGSize(width: 300, height: 300)) { context, size in
            gradient(context, [UIColor(red: 0.20, green: 0.36, blue: 0.48, alpha: 1), UIColor(red: 0.08, green: 0.14, blue: 0.26, alpha: 1)], size)
            radial(context, UIColor(red: 1.0, green: 0.78, blue: 0.48, alpha: 1), at: CGPoint(x: 150, y: 128), radius: 70)
        }
    }

    private static func icon(index: Int) -> Data {
        let palettes: [(UIColor, UIColor, String)] = [
            (.systemCyan, .systemBlue, "face.smiling"), (.white, .systemGray5, "safari"), (.systemPink, .systemRed, "music.note"),
            (.systemYellow, .white, "note.text"), (.white, .systemGray4, "sparkle"), (.systemPurple, .systemIndigo, "number"),
        ]
        let (top, bottom, symbol) = palettes[index % palettes.count]
        return UIGraphicsImageRenderer(size: CGSize(width: 180, height: 180)).pngData { renderer in
            let context = renderer.cgContext
            let size = CGSize(width: 180, height: 180)
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 40).addClip()
            gradient(context, [top, bottom], size)
            let glyph = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 84, weight: .medium))?
                .withTintColor(index == 1 || index == 4 ? .systemBlue : .white, renderingMode: .alwaysOriginal)
            glyph?.draw(in: CGRect(x: 40, y: 40, width: 100, height: 100))
        }
    }

    private static func render(_ size: CGSize, draw: (CGContext, CGSize) -> Void) -> Data {
        UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.9) { draw($0.cgContext, size) }
    }

    private static func gradient(_ context: CGContext, _ colors: [UIColor], _ size: CGSize) {
        let gradient = CGGradient(colorsSpace: nil, colors: colors.map(\.cgColor) as CFArray, locations: nil)!
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
    }

    private static func radial(_ context: CGContext, _ color: UIColor, at center: CGPoint, radius: CGFloat) {
        let gradient = CGGradient(colorsSpace: nil, colors: [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray, locations: nil)!
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }
}
#endif
