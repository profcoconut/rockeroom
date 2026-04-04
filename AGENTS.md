# RockeRoom Agent Notes

## Working Rules

- Prefer repo-local patterns over inventing new abstractions.
- For UI or flow changes, always validate the app on an iOS simulator before declaring the work complete.
- Simulator validation must use the Build iOS Apps plugin workflow, specifically the iOS debugger path, so the app is actually built, launched, and checked on a running simulator.
- The Build iOS Apps plugin is not sufficient by itself. The external `XcodeBuildMCP` server must also be configured in Codex so `mcp__XcodeBuildMCP__...` tools are actually exposed.
- Codex MCP install path: `~/.codex/config.toml` must contain:
  ```toml
  [mcp_servers.XcodeBuildMCP]
  command = "npx"
  args = ["-y", "xcodebuildmcp@latest", "mcp"]
  ```
- If `XcodeBuildMCP` is added or changed, start a new Codex session before expecting the iOS MCP tools to appear. Tool availability is fixed when the session starts.
- Do not treat passing unit or UI tests alone as sufficient proof for UI changes. Use simulator inspection to confirm the screen loads and the critical flow is interactable.
- If the iOS MCP tools are not exposed in the current session, state that explicitly and fall back to simulator-backed `xcodebuild` / XCUITest validation instead of pretending plugin-driven simulator control was performed.
- When the flow depends on a real external URL, real subscription, or live provider behavior, also perform live E2E validation / manual end-to-end testing instead of relying only on stubbed or demo inputs.
- The launch-driven simulator workflow is documented in `docs/testing/live-e2e-workflow.md`. Prefer that scenario contract for repeatable live E2E validation when MCP tap/type controls are unavailable.

<!-- BEGIN COMPOUND CODEX TOOL MAP -->
## Compound Codex Tool Mapping (Claude Compatibility)

This section maps Claude Code plugin tool references to Codex behavior.
Only this block is managed automatically.

Tool mapping:
- Read: use shell reads (cat/sed) or rg
- Write: create files via shell redirection or apply_patch
- Edit/MultiEdit: use apply_patch
- Bash: use shell_command
- Grep: use rg (fallback: grep)
- Glob: use rg --files or find
- LS: use ls via shell_command
- WebFetch/WebSearch: use curl or Context7 for library docs
- AskUserQuestion/Question: present choices as a numbered list in chat and wait for a reply number. For multi-select (multiSelect: true), accept comma-separated numbers. Never skip or auto-configure — always wait for the user's response before proceeding.
- Task/Subagent/Parallel: run sequentially in main thread; use multi_tool_use.parallel for tool calls
- TodoWrite/TodoRead: use file-based todos in todos/ with todo-create skill
- Skill: open the referenced SKILL.md and follow it
- ExitPlanMode: ignore
<!-- END COMPOUND CODEX TOOL MAP -->
