/// Decides which mode should come forward on its own ("It comes to you").
///
/// Suggestions are edge-triggered: Halo reacts when an agent *starts* needing you, not for as
/// long as it does. Leaving Agents mode is therefore always respected until something new
/// happens. Pure and deterministic, so the policy can be tuned against real usage.
public struct ModeSuggester: Sendable {
    public init() {}

    /// The mode to bring forward after the agents changed from `previous` to `current`,
    /// or `nil` to leave the person where they are.
    public func suggestion(showing mode: Mode, previous: [AgentSession], current: [AgentSession]) -> Mode? {
        guard mode != .agents else { return nil }
        let isNewlyWaiting = !Self.attention(in: current).isSubset(of: Self.attention(in: previous))
        return isNewlyWaiting ? .agents : nil
    }

    /// One entry per thing a person is being asked: a session's waiting state and its approvals.
    private static func attention(in sessions: [AgentSession]) -> Set<String> {
        Set(sessions.filter(\.needsAttention).map { session in
            ([session.id, session.status.rawValue] + session.pendingApprovals.map(\.id.uuidString)).joined(separator: "|")
        })
    }
}
