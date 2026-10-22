import Foundation
import HaloCore

public enum HookInstallerError: Error, Equatable {
    /// The file exists but isn't a JSON object. We never overwrite what we can't parse.
    case unreadableConfig(URL)
}

/// Installs and removes Halo's hooks in each agent tool's user-level config.
public struct HookInstaller: Sendable {
    private let home: URL

    public init(home: URL = .homeDirectory) {
        self.home = home
    }

    public func configFile(for tool: AgentTool) -> URL {
        home.appending(path: HookConfiguration.for(tool).path, directoryHint: .notDirectory)
    }

    public func isInstalled(_ tool: AgentTool) throws -> Bool {
        HookConfiguration.for(tool).isInstalled(in: try readConfig(of: tool))
    }

    public func install(_ tool: AgentTool, executable: URL) throws {
        let configuration = HookConfiguration.for(tool)
        let command = configuration.command(executable: executable)
        try writeConfig(configuration.installing(command: command, into: readConfig(of: tool)), of: tool)
    }

    public func uninstall(_ tool: AgentTool) throws {
        let configuration = HookConfiguration.for(tool)
        try writeConfig(configuration.removing(from: readConfig(of: tool)), of: tool)
    }

    private func readConfig(of tool: AgentTool) throws -> JSONValue {
        let file = configFile(for: tool)
        guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else { return [:] }

        let config = try? JSONDecoder().decode(JSONValue.self, from: Data(contentsOf: file))
        guard let config, config.objectValue != nil else { throw HookInstallerError.unreadableConfig(file) }
        return config
    }

    /// Writes atomically, keeping a one-time backup of the user's original file next to it.
    private func writeConfig(_ config: JSONValue, of tool: AgentTool) throws {
        let file = configFile(for: tool)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)

        let backup = file.appendingPathExtension("halo-backup")
        if fileManager.fileExists(atPath: file.path(percentEncoded: false)),
           !fileManager.fileExists(atPath: backup.path(percentEncoded: false)) {
            try fileManager.copyItem(at: file, to: backup)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(config).write(to: file, options: .atomic)
    }
}
