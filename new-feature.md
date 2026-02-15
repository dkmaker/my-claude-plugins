# New Feature: Headless Session Runner for Superpowers

## Problem

When Claude dispatches work to a `-p` session (e.g., executing an implementation plan), the caller has no good way to:
- Monitor progress without bloating its own context window
- Get structured results back (session ID, token usage, success/failure)
- See only relevant output (tool calls, commits, errors) instead of raw stream noise

Currently we `CLAUDECODE= claude -p "..." --output-format stream-json > file.jsonl &` and then manually grep through the output. This is fragile and verbose.

## Proposed Solution

A **wrapper script** (`claude-runner` or similar) that:

### Core Behavior

1. **Accepts a prompt** and optional flags, launches `claude -p` with `--output-format stream-json --verbose --include-partial-messages`
2. **Filters the JSON event stream** in real-time, extracting only:
   - Tool calls (which tools are being used)
   - Text output (assistant messages, summaries)
   - Errors and failures
   - Commit messages (from Bash tool calls matching `git commit`)
   - Token usage / cost estimates
3. **Returns structured results** when done:
   - `session_id` — for resuming later
   - `exit_code` — success/failure
   - `token_usage` — input/output tokens, estimated cost
   - `commits` — list of commits made
   - `errors` — any errors encountered
   - `duration` — wall clock time

### Usage Modes

```bash
# Run in foreground, show filtered progress
claude-runner "Implement task 5 from the plan" --cwd /path/to/worktree

# Run in background (from Bash tool), output to file
claude-runner "Implement task 5" --cwd /path/to/worktree --background --output /tmp/task5.json

# Tail/monitor a running session (like tail -f but filtered)
claude-runner --tail /tmp/task5.json

# Resume a session with a new prompt
claude-runner "Continue from where you left off" --resume <session-id>
```

### Filtered Output (foreground/tail mode)

Instead of thousands of raw JSON events, show only:
```
[10:45:01] Starting session abc123...
[10:45:05] Read: packages/backend/src/db/schema.ts
[10:45:08] Edit: packages/backend/src/db/schema.ts (3 changes)
[10:45:12] Bash: pnpm db:generate
[10:45:15] Write: packages/backend/src/routes/admin/keywords.routes.ts
[10:45:20] Bash: git commit -m "feat: admin keyword routes"
[10:45:22] --- Commit: feat: admin keyword routes ---
[10:47:30] Done. 12 tool calls, 2 commits, 15k tokens, 45s
```

### Return JSON (background mode)

```json
{
  "session_id": "abc-123",
  "exit_code": 0,
  "duration_seconds": 120,
  "token_usage": {
    "input_tokens": 45000,
    "output_tokens": 12000,
    "estimated_cost_usd": 0.45
  },
  "commits": [
    "feat: admin keyword routes",
    "feat: categories tree view"
  ],
  "tool_calls": 24,
  "errors": []
}
```

## Integration with Superpowers

### New Skill: `superpowers:headless-runner`

Wraps the script so Claude can dispatch work cleanly:

```
# In dispatching-parallel-agents or subagent-driven-development:
claude-runner "Implement Task 3" --cwd .worktrees/feature-branch --background --output /tmp/task3.json

# Later, check on it:
claude-runner --tail /tmp/task3.json
```

### Why This Matters

- **Context preservation** — the calling Claude doesn't consume context reading raw stream output
- **Structured monitoring** — just check the summary JSON or tail filtered output
- **Composable** — can dispatch multiple runners in parallel from Bash tool
- **Resumable** — session IDs captured automatically for continuation
- **No nested session issue** — the script handles `CLAUDECODE=` env var unsetting

## Implementation Notes

- Script should be a bash script (or small Node/Python) that wraps `claude -p`
- Must unset `CLAUDECODE` env var to avoid nested session detection
- JSON stream parsing can use `jq` for bash or native JSON parsing for Node
- The `--dangerously-skip-permissions` flag should be configurable (default on for headless)
- Should pass through `--resume`, `--model`, `--allowedTools`, `--append-system-prompt` etc.
- Consider `--max-turns` and `--max-budget-usd` as safety limits

## Open Questions

- Should this be a standalone CLI tool or a bash function sourced by skills?
- Should it support multiple concurrent sessions with a dashboard view?
- How to handle context window limits (>60% usage) — auto-fork with new session?
- Should it integrate with the Task tool to report progress back?
