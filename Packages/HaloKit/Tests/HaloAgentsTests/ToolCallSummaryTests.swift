import Testing
@testable import HaloAgents

@Suite struct ToolCallSummaryTests {
    @Test func prefersTheShellCommand() {
        let call = ToolCallSummary(toolName: "Bash", input: ["command": "npm test", "description": "Run tests"])
        #expect(call.summary == "npm test")
        #expect(call.detail == "Run tests")
    }

    @Test func fallsBackToTheFilePath() {
        let call = ToolCallSummary(toolName: "Edit", input: ["file_path": "/src/App.swift", "old_string": "a"])
        #expect(call.summary == "/src/App.swift")
    }

    @Test func fallsBackToCompactJSONThenTheToolName() {
        #expect(ToolCallSummary(toolName: "mcp__x", input: ["id": 7]).summary == #"{"id":7}"#)
        #expect(ToolCallSummary(toolName: "mcp__x", input: [:]).summary == "mcp__x")
    }

    @Test func truncatesForArmsLengthReading() {
        let call = ToolCallSummary(toolName: "Bash", input: .object(["command": .string(String(repeating: "x", count: 500))]))
        #expect(call.summary.count == ToolCallSummary.maximumLength)
        #expect(call.summary.hasSuffix("…"))
    }
}

