import Foundation
import Testing
import HaloCore
@testable import HaloHookBridge

@Suite struct HookBridgeTests {
    /// Short, unique path: `sun_path` only holds 104 bytes.
    private func temporarySocket() -> URL {
        URL(filePath: "/tmp/halo-\(UUID().uuidString.prefix(8))/hook.sock")
    }

    @Test func relaysInvocationAndReply() async throws {
        let socket = temporarySocket()
        let server = try HookBridgeServer(socket: socket) { invocation in
            HookReply(output: Data("\(invocation.tool.rawValue):\(invocation.payload.count)".utf8))
        }
        try server.start()
        defer { server.stop() }
        try await Task.sleep(for: .milliseconds(100))

        let payload = Data(#"{"hook_event_name":"Stop"}"#.utf8)
        let reply = try await Task.detached {
            try HookBridgeClient.send(HookInvocation(tool: .codex, payload: payload), to: socket)
        }.value

        #expect(String(decoding: reply.output, as: UTF8.self) == "codex:\(payload.count)")
    }

    @Test func socketDirectoryIsOwnerOnly() async throws {
        let socket = temporarySocket()
        let server = try HookBridgeServer(socket: socket) { _ in .passThrough }
        try server.start()
        defer { server.stop() }

        let attributes = try FileManager.default.attributesOfItem(atPath: socket.deletingLastPathComponent().path)
        #expect(attributes[.posixPermissions] as? Int == 0o700)
    }

    @Test func failsFastWhenHelperIsNotRunning() {
        #expect(throws: HookBridgeError.self) {
            try HookBridgeClient.send(HookInvocation(tool: .claudeCode, payload: Data()), to: temporarySocket())
        }
    }

    @Test func rejectsSocketPathsTheKernelCannotHold() {
        let tooLong = URL(filePath: "/tmp/" + String(repeating: "x", count: 200))
        #expect(throws: HookBridgeError.socketPathTooLong(tooLong)) {
            try HookBridgeClient.send(HookInvocation(tool: .claudeCode, payload: Data()), to: tooLong)
        }
    }
}
