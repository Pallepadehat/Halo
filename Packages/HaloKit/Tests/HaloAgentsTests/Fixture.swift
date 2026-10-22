import Foundation

/// Hook payloads shaped after the tools' documented examples.
enum Fixture {
    static let claudePermissionRequest = json("""
    {
      "session_id": "abc123",
      "transcript_path": "/Users/me/.claude/projects/halo/abc123.jsonl",
      "cwd": "/Users/me/Halo",
      "permission_mode": "default",
      "hook_event_name": "PermissionRequest",
      "tool_name": "Bash",
      "tool_input": {
        "command": "rm -rf node_modules",
        "description": "Remove node_modules directory"
      },
      "permission_suggestions": [
        {
          "type": "addRules",
          "rules": [{ "toolName": "Bash", "ruleContent": "rm -rf node_modules" }],
          "behavior": "allow",
          "destination": "localSettings"
        }
      ]
    }
    """)

    static let claudeStop = json("""
    {
      "session_id": "abc123",
      "cwd": "/Users/me/Halo",
      "hook_event_name": "Stop",
      "stop_hook_active": false,
      "last_assistant_message": "I've completed the refactoring."
    }
    """)

    static let claudePrompt = json("""
    {
      "session_id": "abc123",
      "cwd": "/Users/me/Halo",
      "hook_event_name": "UserPromptSubmit",
      "prompt": "Fix the failing tests\\nand then run the linter"
    }
    """)

    static func claudeNotification(type: String) -> Data {
        json("""
        {
          "session_id": "abc123",
          "hook_event_name": "Notification",
          "message": "Claude needs your attention",
          "notification_type": "\(type)"
        }
        """)
    }

    static let cursorPrompt = json("""
    {
      "conversation_id": "conv-1",
      "generation_id": "gen-1",
      "hook_event_name": "beforeSubmitPrompt",
      "workspace_roots": ["/Users/me/Halo"],
      "prompt": "Add a dark mode toggle"
    }
    """)

    private static func json(_ text: String) -> Data {
        Data(text.utf8)
    }
}
