import HaloAgents
import HaloCore
import HaloHookBridge
import Observation
import os

/// Main-actor face of the agent pipeline: runs the hook bridge, mirrors session state for
/// SwiftUI, and manages each tool's hook installation.
@MainActor
@Observable
final class AgentHub {
    enum IntegrationState: Equatable {
        case notInstalled
        case installed
        case failed(String)
    }

    private(set) var sessions: [AgentSession] = []
    private(set) var integrations: [AgentTool: IntegrationState] = [:]

    var needsAttention: Bool {
        sessions.contains(where: \.needsAttention)
    }

    @ObservationIgnored private let coordinator = AgentCoordinator()
    @ObservationIgnored private let installer = HookInstaller()
    @ObservationIgnored private var server: HookBridgeServer?
    @ObservationIgnored private var updates: Task<Void, Never>?
    private static let log = Logger(subsystem: "app.halo", category: "AgentHub")

    func start() {
        guard server == nil else { return }
        HookExecutable.refreshLink()
        refreshIntegrations()

        updates = Task { [coordinator, weak self] in
            for await sessions in coordinator.sessionUpdates {
                self?.sessions = sessions
            }
        }

        do {
            let server = try HookBridgeServer { [coordinator] in await coordinator.handle($0) }
            try server.start()
            self.server = server
        } catch {
            Self.log.error("Hook bridge failed to start: \(error, privacy: .public)")
        }
    }

    func resolve(_ request: ApprovalRequest, with decision: ApprovalDecision) {
        Task { await coordinator.resolve(request.id, with: decision) }
    }

    func setIntegration(_ tool: AgentTool, enabled: Bool) {
        do {
            if enabled {
                try installer.install(tool, executable: HookExecutable.stablePath)
            } else {
                try installer.uninstall(tool)
            }
            integrations[tool] = enabled ? .installed : .notInstalled
        } catch {
            integrations[tool] = .failed(String(describing: error))
        }
    }

    private func refreshIntegrations() {
        for tool in AgentTool.allCases {
            do {
                integrations[tool] = try installer.isInstalled(tool) ? .installed : .notInstalled
            } catch {
                integrations[tool] = .failed(String(describing: error))
            }
        }
    }
}
