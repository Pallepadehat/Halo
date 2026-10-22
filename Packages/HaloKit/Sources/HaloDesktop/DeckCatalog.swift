#if os(macOS)
import AppKit
import HaloCore
import HaloInput

/// Everything the Deck can do: a few built-ins, every Shortcut, and any executable dropped
/// into `~/Library/Application Support/Halo/Scripts`.
///
/// macOS has no API to toggle Focus or Do Not Disturb; a Shortcut using "Set Focus" covers it
/// and shows up here automatically.
public enum DeckCatalog {
    public static let scriptsDirectory = URL.applicationSupportDirectory.appending(path: "Halo/Scripts", directoryHint: .isDirectory)

    enum BuiltIn: String, CaseIterable {
        case playPause, lockScreen, sleepDisplays, missionControl, screenshot, toggleDarkMode

        var action: DeckAction {
            let (title, symbol): (String, String) = switch self {
            case .playPause: (String(localized: "Play/Pause"), "playpause.fill")
            case .lockScreen: (String(localized: "Lock Screen"), "lock.fill")
            case .sleepDisplays: (String(localized: "Sleep Displays"), "moon.zzz.fill")
            case .missionControl: (String(localized: "Mission Control"), "rectangle.3.group.fill")
            case .screenshot: (String(localized: "Screenshot"), "camera.viewfinder")
            case .toggleDarkMode: (String(localized: "Dark Mode"), "circle.lefthalf.filled")
            }
            return DeckAction(id: "builtin.\(rawValue)", title: title, symbol: symbol, kind: .builtIn)
        }
    }

    /// Lists actions. Shortcuts come from the `shortcuts` command, so call this off the main actor.
    public static func actions() async -> [DeckAction] {
        let shortcuts = await run("/usr/bin/shortcuts", ["list"]).map(parseShortcutList) ?? []
        return BuiltIn.allCases.map(\.action)
            + shortcuts.map { DeckAction(id: "shortcut.\($0)", title: $0, symbol: "square.stack.3d.up.fill", kind: .shortcut) }
            + scripts().map { DeckAction(id: "script.\($0)", title: scriptTitle($0), symbol: "terminal.fill", kind: .script) }
    }

    public static func run(_ id: DeckAction.ID, media: MediaController) async {
        let (kind, name) = split(id)
        switch kind {
        case "builtin":
            guard let builtIn = BuiltIn(rawValue: name) else { return }
            await perform(builtIn, media: media)
        case "shortcut":
            _ = await run("/usr/bin/shortcuts", ["run", name])
        case "script":
            // Only files inside the scripts folder: the name can't climb out of it.
            let script = scriptsDirectory.appending(path: name, directoryHint: .notDirectory)
            guard script.deletingLastPathComponent().standardizedFileURL == scriptsDirectory.standardizedFileURL else { return }
            _ = await run(script.path(percentEncoded: false), [])
        default:
            return
        }
    }

    // MARK: - Built-ins

    @MainActor
    private static func perform(_ builtIn: BuiltIn, media: MediaController) async {
        switch builtIn {
        case .playPause:
            media.perform(.playPause, on: nil)
        case .lockScreen:
            KeyChord(key: .q, flags: [.maskControl, .maskCommand]).post()
        case .sleepDisplays:
            _ = await run("/usr/bin/pmset", ["displaysleepnow"])
        case .missionControl:
            _ = await run("/usr/bin/open", ["-a", "Mission Control"])
        case .screenshot:
            KeyChord(key: .five, flags: [.maskShift, .maskCommand]).post()
        case .toggleDarkMode:
            var error: NSDictionary?
            NSAppleScript(source: """
            tell application "System Events" to tell appearance preferences to set dark mode to not dark mode
            """)?.executeAndReturnError(&error)
        }
    }

    // MARK: - Parsing

    /// `shortcuts list` prints one name per line.
    static func parseShortcutList(_ output: String) -> [String] {
        output.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// `"script.Deploy staging.sh"` → `("script", "Deploy staging.sh")`.
    static func split(_ id: DeckAction.ID) -> (kind: Substring, name: String) {
        guard let dot = id.firstIndex(of: ".") else { return (id[...], "") }
        return (id[..<dot], String(id[id.index(after: dot)...]))
    }

    /// `"deploy-staging.sh"` → `"Deploy staging"`.
    static func scriptTitle(_ fileName: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        return base.prefix(1).uppercased() + base.dropFirst()
    }

    private static func scripts() -> [String] {
        let fileManager = FileManager.default
        let names = (try? fileManager.contentsOfDirectory(atPath: scriptsDirectory.path(percentEncoded: false))) ?? []
        return names.filter { name in
            !name.hasPrefix(".") && fileManager.isExecutableFile(atPath: scriptsDirectory.appending(path: name).path(percentEncoded: false))
        }.sorted()
    }

    /// Runs a command to completion off the main actor and returns its standard output.
    @concurrent
    private static func run(_ executable: String, _ arguments: [String]) async -> String? {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
    }
}
#endif
