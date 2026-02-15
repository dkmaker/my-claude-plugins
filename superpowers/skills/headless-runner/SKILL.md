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

### Model Selection

Choose the model based on task complexity:

| Model | Use when | Examples |
|---|---|---|
| **haiku** | Simple, mechanical tasks with clear instructions | Rename variables, add boilerplate, run formatters, simple tests, file moves |
| **sonnet** | Standard implementation work (default) | Implement features from a clear plan, write tests, fix known bugs, refactoring |
| **opus** | Complex tasks requiring deep reasoning | Architectural changes, cross-cutting refactors, debugging subtle issues, tasks with ambiguous requirements |

**Rules of thumb:**
- If the plan has exact code to copy — **haiku** (cheapest, fastest)
- If the plan describes what to build but the engineer decides how — **sonnet** (best balance)
- If the task needs judgment calls, design decisions, or debugging — **opus** (most capable)
- When in doubt, use **sonnet** — it handles most implementation tasks well

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

### Prompt Construction

Detect which mode applies and construct the prompt accordingly:

#### Plan-based mode (called from writing-plans workflow)

If a plan file exists (e.g., `docs/plans/YYYY-MM-DD-feature.md`), point the runner at it and let `executing-plans` handle everything:

```
--prompt "Use the superpowers:executing-plans skill to implement the plan at docs/plans/2026-02-15-feature.md. Work in the current directory."
```

The `executing-plans` skill handles task ordering, batching, verification, and commits internally — do NOT inline task text or micro-manage the steps.

#### Ad-hoc mode (called directly without a plan)

When there is no plan file, construct a self-contained prompt:
1. Describe the task clearly and completely (the session has no prior context)
2. Include specific instructions: what to build, where, how to test
3. What to report: "When done, summarize what you implemented and any issues."

```
--prompt "Create a spinning Hello World HTML page at spinning-hello.html. Dark background, colorful text, CSS animations. No external dependencies."
```

### Batching Pattern

```
Batch 1: --prompt "Use superpowers:executing-plans to implement docs/plans/feature.md"
  Result: context_warning: false
  → Next batch can resume

Batch 2: --resume <session-id> --prompt "Continue executing the plan"
  Result: context_warning: true
  → Next batch must be a new session

Batch 3: --prompt "Use superpowers:executing-plans to implement docs/plans/feature.md. Status: Tasks 1-6 complete (auth middleware, user model, login endpoint). Continue from Task 7."
  (new session, fresh context — brief status helps avoid re-doing work)
```

For ad-hoc mode, follow the same context_warning logic but include full task details in each new session prompt.

### Resume Prompt

- **Plan-based (resume):** `"Continue executing the plan"` — the session already has full context
- **Plan-based (new session after context warning):** Always instruct to use `executing-plans` with the plan path, plus a brief status of what was completed (task numbers and short descriptions) so the new session picks up where the last left off
- **Ad-hoc:** Include what was completed and what remains, since there is no plan file to reference

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
