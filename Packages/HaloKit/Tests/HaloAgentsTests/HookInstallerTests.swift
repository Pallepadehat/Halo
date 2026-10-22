import Foundation
import Testing
import HaloCore
@testable import HaloAgents

@Suite struct HookInstallerTests {
    private let home = FileManager.default.temporaryDirectory.appending(path: "halo-home-\(UUID().uuidString)")
    private let executable = URL(filePath: "/Users/me/Library/Application Support/Halo/bin/halo-hook")
    private var installer: HookInstaller { HookInstaller(home: home) }

    private func config(of tool: AgentTool) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: installer.configFile(for: tool)))
    }

    private func seed(_ tool: AgentTool, with json: String) throws {
        let file = installer.configFile(for: tool)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(json.utf8).write(to: file)
    }

    @Test func installsClaudeCodeHooksAlongsideTheUsersSettings() throws {
        try seed(.claudeCode, with: #"{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}"#)

        try installer.install(.claudeCode, executable: executable)

        let config = try config(of: .claudeCode)
        #expect(config["model"] == "opus")
        #expect(config["hooks"]?["Stop"]?.arrayValue?.count == 2)
        #expect(config["hooks"]?["PermissionRequest"] == [[
            "hooks": [[
                "type": "command",
                "command": "'/Users/me/Library/Application Support/Halo/bin/halo-hook' claude-code",
                "timeout": 120,
            ]],
        ]])
        #expect(try installer.isInstalled(.claudeCode))
    }

    @Test func installingTwiceIsIdempotent() throws {
        try installer.install(.codex, executable: executable)
        let once = try config(of: .codex)
        try installer.install(.codex, executable: executable)
        #expect(try config(of: .codex) == once)
    }

    @Test func uninstallRestoresTheUsersOwnHooks() throws {
        let original = #"{"hooks":{"Stop":[{"hooks":[{"command":"say done","type":"command"}]}]}}"#
        try seed(.claudeCode, with: original)

        try installer.install(.claudeCode, executable: executable)
        try installer.uninstall(.claudeCode)

        #expect(try config(of: .claudeCode) == JSONDecoder().decode(JSONValue.self, from: Data(original.utf8)))
        #expect(try !installer.isInstalled(.claudeCode))
    }

    @Test func cursorUsesTheFlatVersionedLayout() throws {
        try installer.install(.cursor, executable: executable)
        let config = try config(of: .cursor)
        #expect(config["version"] == 1)
        #expect(config["hooks"]?["stop"]?.arrayValue?.first?["command"]?.stringValue?.hasSuffix(" cursor") == true)
        #expect(config["hooks"]?["beforeShellExecution"] == nil)
    }

    @Test func refusesToOverwriteAConfigItCannotParse() throws {
        try seed(.claudeCode, with: "{ not json")
        #expect(throws: HookInstallerError.unreadableConfig(installer.configFile(for: .claudeCode))) {
            try installer.install(.claudeCode, executable: executable)
        }
    }

    @Test func backsUpTheOriginalOnce() throws {
        try seed(.claudeCode, with: #"{"model":"opus"}"#)
        try installer.install(.claudeCode, executable: executable)
        try installer.uninstall(.claudeCode)

        let backup = installer.configFile(for: .claudeCode).appendingPathExtension("halo-backup")
        #expect(try String(contentsOf: backup, encoding: .utf8) == #"{"model":"opus"}"#)
    }

    @Test func quotesExecutablePathsForTheShell() {
        let command = HookConfiguration.for(.codex).command(executable: URL(filePath: "/Apps/It's Halo/halo-hook"))
        #expect(command == #"'/Apps/It'\''s Halo/halo-hook' codex"#)
    }
}
