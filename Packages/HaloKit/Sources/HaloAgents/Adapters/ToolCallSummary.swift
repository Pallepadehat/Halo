import Foundation

/// Boils a tool call down to the one line worth reading from arm's length.
struct ToolCallSummary {
    static let maximumLength = 240

    let summary: String
    let detail: String?

    init(toolName: String, input: JSONValue?) {
        let headline = Self.headlineKeys.lazy.compactMap { input?[$0]?.stringValue }.first
        summary = Self.truncated(headline ?? Self.compactJSON(input) ?? toolName)
        detail = input?["description"]?.stringValue.map(Self.truncated)
    }

    /// The inputs that best identify a call, in order: shell commands, files, then searches.
    private static let headlineKeys = ["command", "file_path", "path", "url", "pattern", "query"]

    private static func compactJSON(_ input: JSONValue?) -> String? {
        guard let input, input != .object([:]) else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(input)).map { String(decoding: $0, as: UTF8.self) }
    }

    private static func truncated(_ text: String) -> String {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.count > maximumLength else { return line }
        return line.prefix(maximumLength - 1) + "…"
    }
}
