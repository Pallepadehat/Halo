import Foundation
import HaloCore

/// One hook call, relayed verbatim from `halo-hook` to the Mac helper.
public struct HookInvocation: Codable, Sendable, Equatable {
    public let tool: AgentTool
    /// The JSON object the agent wrote to the hook's stdin, untouched.
    public let payload: Data

    public init(tool: AgentTool, payload: Data) {
        self.tool = tool
        self.payload = payload
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
