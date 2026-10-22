#if DEBUG
import Foundation
import HaloCore
import HaloTransport

/// Realistic sample data for previews and for `-HaloDemo` launches, so every mode can be
/// designed on a real iPad without a Mac attached.
enum DemoData {
    static let mac = DeviceIdentity(id: UUID(), name: "Patrick's MacBook Pro")

    /// Ten minutes at the helper's cadence: a calm baseline, then a build pegging the CPU.
    static func metricsHistory(endingAt end: Date = .now) -> [SystemMetrics] {
        (0..<300).map { index in
            let t = Double(index)
            let build = index > 270
            return SystemMetrics(
                cpu: build ? 0.82 + 0.06 * sin(t) : 0.14 + 0.06 * sin(t / 9) + 0.04 * sin(t / 2.3),
                memory: 0.61 + 0.03 * sin(t / 40),
                memoryUsedBytes: 21_800_000_000,
                freeStorageBytes: 212_000_000_000,
                totalStorageBytes: 994_000_000_000,
                networkBytesInPerSecond: Int64(180_000 + 140_000 * max(0, sin(t / 6)) + (index % 47 == 0 ? 2_400_000 : 0)),
                networkBytesOutPerSecond: 42_000,
                topCPUProcess: build ? ProcessUsage(name: "Xcode", share: 0.63) : nil,
                timestamp: end.addingTimeInterval(Double(index - 299) * 2)
            )
        }
    }

    static func agents() -> [AgentSession] {
        let claude = AgentSession.id(tool: .claudeCode, nativeID: "demo-1")
        return [
            AgentSession(
                id: claude,
                tool: .claudeCode,
                title: "Add the Pulse mode",
                project: "Halo",
                status: .waitingForApproval,
                pendingApprovals: [
                    ApprovalRequest(sessionID: claude, toolName: "Bash", summary: "swift test --package-path Packages/HaloKit", detail: "Run the package tests"),
                ]
            ),
            AgentSession(
                id: AgentSession.id(tool: .codex, nativeID: "demo-2"),
                tool: .codex,
                title: "Refactor the settings screen",
                project: "Orbit",
                status: .running
            ),
            AgentSession(
                id: AgentSession.id(tool: .cursor, nativeID: "demo-3"),
                tool: .cursor,
                title: "Write release notes",
                project: "Website",
                status: .waitingForReply,
                latestMessage: "Drafted the notes for 2.4. Want me to shorten the intro?"
            ),
        ]
    }
}
#endif
