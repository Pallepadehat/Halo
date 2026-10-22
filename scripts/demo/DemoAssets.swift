// Exports real pictures from this Mac for the iPad's `-HaloDemo` mode, so screenshots show
// genuine app icons, a real wallpaper and real artwork instead of drawn stand-ins.
//
//   swift scripts/demo/DemoAssets.swift <out directory> [wallpaper] -AppleIconAppearanceTheme RegularLight
//
// The wallpaper defaults to this Mac's desktop picture.
//
// The trailing flag overrides the icon style for this process only, so the icons come out in
// the default colours even when the Mac's icons are set to Dark or Tinted.
// Writes `manifest.json`, `wallpaper.jpg`, `artwork.jpg` and `icons/*.png`.
import AppKit

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    print("usage: swift DemoAssets.swift <out directory>")
    exit(1)
}
let out = URL(filePath: arguments[1], directoryHint: .isDirectory)
try? FileManager.default.removeItem(at: out)
try FileManager.default.createDirectory(at: out.appending(path: "icons"), withIntermediateDirectories: true)

/// The Dock in the screenshots: familiar apps, Finder first, as the Mac's own Dock has it.
typealias DockApp = (id: String, name: String, path: String)
let familiarApps: [DockApp] = [
    ("com.apple.finder", "Finder", "/System/Library/CoreServices/Finder.app"),
    ("com.apple.Safari", "Safari", "/Applications/Safari.app"),
    ("com.apple.MobileSMS", "Messages", "/System/Applications/Messages.app"),
    ("com.apple.mail", "Mail", "/System/Applications/Mail.app"),
    ("com.apple.Music", "Music", "/System/Applications/Music.app"),
    ("com.apple.Notes", "Notes", "/System/Applications/Notes.app"),
    ("com.apple.Photos", "Photos", "/System/Applications/Photos.app"),
    ("com.apple.Terminal", "Terminal", "/System/Applications/Utilities/Terminal.app"),
    ("com.apple.systempreferences", "System Settings", "/System/Applications/System Settings.app"),
]
let dock: [DockApp] = familiarApps.map { app in
    // Safari's /Applications entry is a symlink, whose icon carries an alias arrow.
    (id: app.id, name: app.name, path: URL(filePath: app.path).resolvingSymlinksInPath().path)
}.filter { FileManager.default.fileExists(atPath: $0.path) }

func png(_ image: NSImage, side: CGFloat) -> Data? {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

func jpeg(_ image: NSImage, maxDimension: CGFloat) -> Data? {
    guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    let scale = min(1, maxDimension / CGFloat(max(cg.width, cg.height)))
    let size = NSSize(width: CGFloat(cg.width) * scale, height: CGFloat(cg.height) * scale)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(origin: .zero, size: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
}

var manifest: [String: Any] = [:]

manifest["apps"] = dock.enumerated().compactMap { index, app -> [String: String]? in
    let file = "icons/\(index).png"
    guard let data = png(NSWorkspace.shared.icon(forFile: app.path), side: 180) else { return nil }
    try? data.write(to: out.appending(path: file))
    return ["id": app.id, "name": app.name, "icon": file]
}

// The picture given, else the main display's, else Sonoma's when it can't be read (e.g. an Aerial).
let chosenWallpaper = arguments.count > 2 && !arguments[2].hasPrefix("-") ? URL(filePath: arguments[2]) : nil
let wallpaperURL = chosenWallpaper ?? NSScreen.main.flatMap { NSWorkspace.shared.desktopImageURL(for: $0) }
let wallpaper = wallpaperURL.flatMap(NSImage.init(contentsOf:)) ?? NSImage(contentsOfFile: "/System/Library/Desktop Pictures/Sonoma.heic")
if let wallpaper, let data = jpeg(wallpaper, maxDimension: 640) {
    try data.write(to: out.appending(path: "wallpaper.jpg"))
    manifest["wallpaper"] = "wallpaper.jpg"
}

// Whatever Music has loaded, paused or playing. Asking never launches Music.
let script = """
if application "Music" is not running then return ""
tell application "Music"
  if not (exists current track) then return ""
  set t to current track
  set info to (name of t) & tab & (artist of t) & tab & (album of t) & tab & (duration of t) & tab & (player state is playing)
  try
    set artData to raw data of artwork 1 of t
  on error
    return info
  end try
end tell
-- Outside Music's tell block: file commands belong to the script, not to Music.
set f to open for access (POSIX file "\(out.appending(path: "artwork.raw").path)") with write permission
write artData to f
close access f
return info
"""
/// Runs through `osascript`, which already holds Automation consent for Music in most Terminals.
func runAppleScript(_ source: String) -> String {
    let process = Process()
    process.executableURL = URL(filePath: "/usr/bin/osascript")
    process.arguments = ["-e", source]
    let pipe = Pipe()
    process.standardOutput = pipe
    try? process.run()
    process.waitUntilExit()
    return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .newlines)
}

let result = runAppleScript(script)
if !result.isEmpty {
    let fields = result.components(separatedBy: "\t")
    if fields.count == 5 {
        manifest["track"] = ["title": fields[0], "artist": fields[1], "album": fields[2],
                             "duration": Double(fields[3].replacingOccurrences(of: ",", with: ".")) ?? 200,
                             "isPlaying": fields[4] == "true"]
    }
    let raw = out.appending(path: "artwork.raw")
    if let image = NSImage(contentsOf: raw), let data = jpeg(image, maxDimension: 600) {
        try data.write(to: out.appending(path: "artwork.jpg"))
        manifest["artwork"] = "artwork.jpg"
    }
    try? FileManager.default.removeItem(at: raw)
}

let json = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
try json.write(to: out.appending(path: "manifest.json"))
print("Exported \(dock.count) icons\(manifest["wallpaper"] != nil ? ", the wallpaper" : "")\(manifest["artwork"] != nil ? " and Music's artwork" : "") to \(out.path)")
