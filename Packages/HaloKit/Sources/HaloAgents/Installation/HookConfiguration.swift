import Foundation
import HaloCore

/// Where a tool reads its hooks from, which events Halo subscribes to, and how to edit
/// that file without disturbing anything the user put there.
public struct HookConfiguration: Sendable {
    public struct Subscription: Sendable, Equatable {
        public let event: String
        /// Seconds the tool waits for `halo-hook` before giving up on it.
        public let timeout: Int
    }

    enum Layout: Sendable {
        /// `{"hooks": {"Event": [{"hooks": [{"type": "command", "command": …}]}]}}`. Claude Code and Codex.
        case matcherGroups
        /// `{"version": 1, "hooks": {"event": [{"command": …}]}}`. Cursor.
        case flat
    }

    /// Generous enough to cover `AgentCoordinator.defaultApprovalWindow`, so the agent never
    /// kills a hook that's still waiting on a human.
    public static let approvalTimeout = 120
    /// Everything else answers immediately; a stuck helper must never stall the agent.
    public static let eventTimeout = 5
    /// Identifies handlers Halo owns, so install is idempotent and uninstall is surgical.
    static let ownershipMarker = "halo-hook"

    public let tool: AgentTool
    /// Relative to the user's home directory.
    public let path: String
    let layout: Layout
    public let subscriptions: [Subscription]

    public static func `for`(_ tool: AgentTool) -> HookConfiguration {
        switch tool {
        case .claudeCode:
            HookConfiguration(tool: tool, path: ".claude/settings.json", layout: .matcherGroups, subscriptions: [
                .event("SessionStart"), .event("UserPromptSubmit"), .approval("PermissionRequest"),
                .event("PostToolUse"), .event("Notification"), .event("Stop"), .event("SessionEnd"),
            ])
        case .codex:
            HookConfiguration(tool: tool, path: ".codex/hooks.json", layout: .matcherGroups, subscriptions: [
                .event("SessionStart"), .event("UserPromptSubmit"), .approval("PermissionRequest"),
                .event("PostToolUse"), .event("Stop"),
            ])
        case .cursor:
            HookConfiguration(tool: tool, path: ".cursor/hooks.json", layout: .flat, subscriptions: [
                .event("beforeSubmitPrompt"), .event("stop"), .event("sessionEnd"),
            ])
        }
    }

    /// The shell command a tool runs for each hook, e.g. `'/path/to/halo-hook' claude-code`.
    public func command(executable: URL) -> String {
        "\(Self.shellQuoted(executable.path(percentEncoded: false))) \(tool.rawValue)"
    }

    func isInstalled(in config: JSONValue) -> Bool {
        subscriptions.allSatisfy { subscription in
            handlers(for: subscription.event, in: config).contains(where: Self.isOwned)
        }
    }

    /// Adds Halo's handlers, replacing any from a previous install.
    func installing(command: String, into config: JSONValue) -> JSONValue {
        var config = removing(from: config)
        var hooks = config["hooks"]?.objectValue ?? [:]
        for subscription in subscriptions {
            var entries = hooks[subscription.event]?.arrayValue ?? []
            entries.append(entry(command: command, timeout: subscription.timeout))
            hooks[subscription.event] = .array(entries)
        }
        config["hooks"] = .object(hooks)
        if layout == .flat, config["version"] == nil {
            config["version"] = 1
        }
        return config
    }

    /// Removes Halo's handlers and any containers left empty, leaving everything else as it was.
    func removing(from config: JSONValue) -> JSONValue {
        guard let hooks = config["hooks"]?.objectValue else { return config }

        var remaining: [String: JSONValue] = [:]
        for (event, value) in hooks {
            guard let entries = value.arrayValue else {
                remaining[event] = value
                continue
            }
            let kept = entries.compactMap(removingOwnedHandlers)
            if !kept.isEmpty { remaining[event] = .array(kept) }
        }

        var config = config
        config["hooks"] = remaining.isEmpty ? nil : .object(remaining)
        return config
    }

    // MARK: - Layout details

    private func entry(command: String, timeout: Int) -> JSONValue {
        switch layout {
        case .matcherGroups:
            ["hooks": [["type": "command", "command": .string(command), "timeout": .number(Double(timeout))]]]
        case .flat:
            ["command": .string(command), "timeout": .number(Double(timeout))]
        }
    }

    private func handlers(for event: String, in config: JSONValue) -> [JSONValue] {
        let entries = config["hooks"]?[event]?.arrayValue ?? []
        switch layout {
        case .matcherGroups: return entries.flatMap { $0["hooks"]?.arrayValue ?? [] }
        case .flat: return entries
        }
    }

    /// The entry without Halo's handlers, or `nil` if nothing of the user's is left in it.
    private func removingOwnedHandlers(from entry: JSONValue) -> JSONValue? {
        switch layout {
        case .flat:
            return Self.isOwned(entry) ? nil : entry
        case .matcherGroups:
            guard let handlers = entry["hooks"]?.arrayValue else { return entry }
            let kept = handlers.filter { !Self.isOwned($0) }
            if kept.isEmpty, kept.count != handlers.count { return nil }
            var entry = entry
            entry["hooks"] = .array(kept)
            return entry
        }
    }

    private static func isOwned(_ handler: JSONValue) -> Bool {
        handler["command"]?.stringValue?.contains(ownershipMarker) == true
    }

    private static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }
}

private extension HookConfiguration.Subscription {
    static func event(_ name: String) -> Self {
        Self(event: name, timeout: HookConfiguration.eventTimeout)
    }

    static func approval(_ name: String) -> Self {
        Self(event: name, timeout: HookConfiguration.approvalTimeout)
    }
}
