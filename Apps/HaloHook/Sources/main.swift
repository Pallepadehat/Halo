// halo-hook <tool>
//
// Agent tools run this once per hook call. It relays the hook's stdin to the Halo helper and
// prints the helper's reply. It holds no logic of its own and fails open: if the helper isn't
// running it prints nothing, so the agent behaves exactly as if Halo weren't installed.

import Foundation
import HaloCore
import HaloHookBridge

guard CommandLine.arguments.count == 2, let tool = AgentTool(rawValue: CommandLine.arguments[1]) else {
    let tools = AgentTool.allCases.map(\.rawValue).joined(separator: "|")
    FileHandle.standardError.write(Data("usage: halo-hook <\(tools)>\n".utf8))
    exit(EX_USAGE)
}

let payload = FileHandle.standardInput.readDataToEndOfFile()

if let reply = try? HookBridgeClient.send(HookInvocation(tool: tool, payload: payload, parentProcess: getppid())) {
    FileHandle.standardOutput.write(reply.output)
}
