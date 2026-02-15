---
name: headless-runner
description: Launch claude -p sessions in background with filtered output and structured results. Use when executing implementation plans via background headless sessions instead of subagents or manual parallel sessions.
---

# Headless Session Runner

## Overview

Launch a `claude -p` session in the background via the Bash tool. The wrapper filters the JSON stream to compact one-liner progress and returns a structured JSON summary with context awareness.

**When to use this** instead of alternatives:

| Mode | Use when |
|---|---|
| Subagent-Driven | Tasks are small, need review between each, want to stay in current session |
| Parallel Session | Want human-in-the-loop checkpoints between batches |
| **Headless Runner** | Want to dispatch work to a background session with minimal context cost, auto context awareness, and structured results |

## How to Launch

Use the Bash tool with `run_in_background: true`:

```bash
node SKILL_DIR/claude-runner.js \
  --prompt "Your task instructions here" \
  --cwd /path/to/working/directory \
  --model sonnet
```

Replace `SKILL_DIR` with the base directory path shown at the top when this skill loads.

**No `CLAUDECODE=` prefix needed.** The script automatically unsets the `CLAUDECODE` environment variable before spawning `claude -p`, so it works correctly when called from within a Claude Code session via the Bash tool.

### CLI Options

| Flag | Default | Description |
|---|---|---|
| `--prompt <text>` | (required*) | Task prompt for the session |
| `--resume <id>` | (required*) | Resume an existing session |
| `--cwd <path>` | current dir | Working directory |
| `--model <alias>` | sonnet | Model: sonnet, opus, haiku |
| `--max-turns <n>` | 100 | Max agentic turns |
| `--max-budget <usd>` | disabled | Max dollar spend |
| `--system-prompt <text>` | none | Appended to system prompt |
| `--allowed-tools <list>` | all | Comma-separated tool list |
| `--timeout <seconds>` | disabled | Kill session after N seconds |

*One of `--prompt` or `--resume` is required. Both can be used together (resume + new prompt).

## Reading Results

When the background Bash task completes, read the output. The last section after `---CLAUDE-RUNNER-RESULT---` is a JSON summary:

```json
{
  "session_id": "abc-123",
  "model": "claude-sonnet-4-5-20250929",
  "exit_code": 0,
  "duration_seconds": 120,
  "cost_usd": 0.45,
  "tokens": {
    "input": 45000,
    "output": 12000,
    "cache_read": 30000,
    "cache_creation": 15000,
    "context_window": 200000,
    "max_output": 32000,
    "context_used_pct": 38
  },
  "tool_calls": 24,
  "git": {
    "start_sha": "a1b2c3d",
    "end_sha": "f4e5d6a",
    "commits": ["f4e5d6a feat: keyword routes"],
    "changed_files": 8,
    "insertions": 245,
    "deletions": 12,
    "uncommitted_changes": 0
  },
  "errors": [],
  "context_warning": false,
  "resume_command": "node /path/to/claude-runner.js --resume abc-123 --prompt \"Continue\""
}
```

## Context-Aware Batching

**Critical:** Check `context_warning` after each run.

- `context_warning: false` — safe to `--resume` this session for the next batch
- `context_warning: true` — context usage is above 60%. Start a **new session** with `--prompt` instead of `--resume`

**How context is measured:** The wrapper tracks per-turn token usage from the stream (not the aggregate which double-counts the system prompt across turns). It uses the **last turn's** token counts divided by the effective context window (`context_window - max_output`) to calculate the true point-in-time context usage. The `max_output` field shows how many tokens are reserved for the model's response.

### Batching Pattern

```
Batch 1: --prompt "Implement Tasks 1-3 from the plan: [full task text]"
  Result: context_warning: false
  → Next batch can resume

Batch 2: --resume <session-id> --prompt "Continue with Tasks 4-6: [full task text]"
  Result: context_warning: true
  → Next batch must be a new session

Batch 3: --prompt "Implement Tasks 7-9 from the plan: [full task text]"
  (new session, fresh context)
```

### Prompt Construction

When dispatching a batch, include in the prompt:
1. The full task descriptions from the plan (don't make it read files)
2. Clear instructions: "Work in the current directory. Follow TDD. Commit after each task."
3. What to report: "When done, summarize what you implemented and any issues."

### Resume Prompt

When resuming, include what was already completed:
"Continue from where you left off. Tasks 1-3 are complete. Now implement Tasks 4-6: [full task text]"

## Error Handling

| Summary field | Meaning |
|---|---|
| `exit_code: 0` | Success |
| `exit_code: 1` | Claude session failed — check `errors` array |
| `exit_code: -1` | Killed by timeout |
| `incomplete: true` | Stream ended without proper result event |
| `killed: true` | Process was killed (timeout or signal) |

If `exit_code != 0`, report the errors to the user and ask how to proceed.

## Integration

- **Called by:** writing-plans (option 3), or directly when user wants background execution
- **Pairs with:** using-git-worktrees (for isolated workspaces)
- **Completes with:** finishing-a-development-branch (when all batches done)
