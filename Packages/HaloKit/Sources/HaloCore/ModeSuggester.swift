/// Decides which mode should come forward on its own ("It comes to you").
/// Pure and deterministic so it can be tuned against real usage.
public struct ModeSuggester: Sendable {
    public init() {}

    /// Returns a mode to surface, or nil to leave the user where they are.
    /// A manual pick always wins until `userOverride` is cleared.
    public func suggest(
        current: Mode,
        userOverride: Mode?,
        agents: [AgentSession]
    ) -> Mode? {
        if let userOverride { return userOverride == current ? nil : userOverride }
        if agents.contains(where: \.needsAttention), current != .agents {
            return .agents
        }
        return nil
    }
}
