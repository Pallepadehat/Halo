/// Decides when agents should be brought forward on their own ("It comes to you").
///
/// Edge-triggered: Halo reacts when an agent *starts* needing you, not for as long as it
/// does, so moving away from the agents is respected until something new happens.
public enum AgentAttention {
    public static func isNewlyNeeded(previous: [AgentSession], current: [AgentSession]) -> Bool {
        !requests(in: current).isSubset(of: requests(in: previous))
    }

    /// One entry per thing a person is being asked: a session's waiting state and its approvals.
    private static func requests(in sessions: [AgentSession]) -> Set<String> {
        Set(sessions.filter(\.needsAttention).map { session in
            ([session.id, session.status.rawValue] + session.pendingApprovals.map(\.id.uuidString)).joined(separator: "|")
        })
    }
}
