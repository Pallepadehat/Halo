import Foundation
import HaloCore

/// One hook call, relayed verbatim from `halo-hook` to the Mac helper.
public struct HookInvocation: Codable, Sendable, Equatable {
    public let tool: AgentTool
    /// The JSON object the agent wrote to the hook's stdin, untouched.
    public let payload: Data
    /// The agent process that ran the hook, so the helper can find the terminal it lives in.
    public let parentProcess: Int32?

    public init(tool: AgentTool, payload: Data, parentProcess: Int32? = nil) {
        self.tool = tool
        self.payload = payload
        self.parentProcess = parentProcess
    }
}

/// What `halo-hook` should print to stdout before exiting.
public struct HookReply: Codable, Sendable, Equatable {
    public let output: Data

    public init(output: Data) {
        self.output = output
    }

    /// No opinion: the agent carries on exactly as if Halo weren't installed.
    public static let passThrough = HookReply(output: Data())
}
