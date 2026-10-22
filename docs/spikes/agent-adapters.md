# Spike: agent adapters

Oct 22, 2026 · answers the PRD open question *"Which agent tools expose a reliable way to read state and approve actions?"*

## Verdict

| Tool        | Read state | Approve / deny from iPad | Mechanism                                   |
| ----------- | ---------- | ------------------------ | ------------------------------------------- |
| Claude Code | Yes        | **Yes**                  | Command hooks, `PermissionRequest` decision |
| Codex       | Yes        | **Yes**                  | Command hooks, `PermissionRequest` decision |
| Cursor      | Yes        | **No — ships read-only** | Command hooks, no "approval needed" event   |

All three tools support **command hooks**: the tool spawns a process, writes one JSON object to its stdin, and reads JSON from its stdout. That gives us one integration shape for all of them.

## Architecture

```
 agent CLI ──spawns──▶ halo-hook <tool> ──unix socket──▶ Halo Helper ──local link──▶ iPad
            stdin JSON                    HookInvocation   AgentCoordinator
            stdout JSON ◀───────────────── HookReply ◀──── (waits for a decision)
```

- `halo-hook` is a tiny relay embedded in the helper's bundle. It has no logic: it forwards the raw payload and prints whatever the helper replies.
- **It fails open.** If the helper isn't running, `halo-hook` prints nothing and exits 0, so the agent behaves exactly as if Halo weren't installed.
- The socket lives in `~/Library/Application Support/Halo/` with `0700` permissions, so only the current user can talk to it.
- All parsing and policy live in `HaloAgents`, so they can be unit-tested without spawning anything.

## Claude Code

Docs: https://code.claude.com/docs/en/hooks · config: `~/.claude/settings.json`

- Common stdin fields: `session_id`, `transcript_path`, `cwd`, `permission_mode`, `hook_event_name`.
- `PermissionRequest` fires only when Claude would show a permission dialog. Input has `tool_name`, `tool_input`, and `permission_suggestions`.
  - Allow: `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}`
  - Deny: same, with `"behavior":"deny","message":"…"`.
  - No decision: Claude shows its normal dialog.
- Useful events: `SessionStart`, `UserPromptSubmit` (`prompt`), `PostToolUse`, `Notification` (`notification_type: idle_prompt`), `Stop` (`last_assistant_message`), `SessionEnd`.
- Default command timeout is 600 s, so the hook can hold a request while the user decides on the iPad.

## Codex

Docs: https://learn.chatgpt.com/docs/hooks · config: `~/.codex/hooks.json`

- Same shape as Claude Code: the same `hooks → event → matcher group → handlers` structure and the same `PermissionRequest` output.
- `PermissionRequest` "runs when Codex is about to ask for approval" and is skipped for commands that don't need approval. If several hooks decide, any `deny` wins.
- **Trust gate:** Codex skips non-managed hooks until the user trusts them via `/hooks` in the CLI. Trust is tied to the hook's hash, so changing the command means trusting it again. Onboarding must tell the user this.
- There's no `Notification` event. `Stop` carries `last_assistant_message`.

## Cursor

Docs: https://cursor.com/docs/agent/hooks · config: `~/.cursor/hooks.json` (`"version": 1`)

- Common fields: `conversation_id`, `generation_id`, `hook_event_name`, `workspace_roots`. `sessionStart` sends `session_id` instead.
- **No approval event.** `beforeShellExecution`, `beforeMCPExecution` and `preToolUse` fire for *every* call, not only the ones that need approval. Holding them would stall every command, and answering `allow` would bypass Cursor's own safety rules. Community reports also say `ask` is unreliable, and malformed output fails open.
- **Decision:** read-only, per the PRD mitigation. We only subscribe to `sessionStart`, `beforeSubmitPrompt`, `stop` and `sessionEnd`.

## Policy decisions

- **Approval window:** the helper holds a permission request for up to 90 s, waiting for a decision from Halo. If none arrives, it replies "no decision" and the agent shows its own prompt on the Mac. The hook `timeout` is set above that window so the agent never kills the relay first.
- **A turn ending counts as waiting.** When a turn ends (`Stop`), the session becomes *waiting for reply*. That's what lets Agents come forward when an agent is done.
- **Quick replies aren't wired up yet.** A Claude Code or Codex `Stop` hook can return `decision: block` with a `reason` that becomes the next prompt, which is a viable route for quick replies. Spike that separately.
