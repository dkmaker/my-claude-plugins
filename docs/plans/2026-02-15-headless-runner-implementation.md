# Headless Session Runner Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a 3rd execution mode to superpowers that launches `claude -p` in the background via a Node.js wrapper, filters stream output to compact one-liners, and returns structured JSON summary with context awareness.

**Architecture:** A Node.js script (`claude-runner.js`) spawns `claude -p` with `--output-format stream-json`, reads stdout line-by-line, filters events to one-liner progress, tracks git state, and outputs a JSON summary on completion. A SKILL.md teaches Claude when/how to use it. The `writing-plans` skill is updated to offer this as option 3 at handoff.

**Tech Stack:** Node.js (built-in modules only: child_process, readline, path, fs)

---

### Task 1: Create claude-runner.js — CLI argument parsing and process spawning

**Files:**
- Create: `superpowers/skills/headless-runner/claude-runner.js`

**Step 1: Create the script with argument parsing**

Create `superpowers/skills/headless-runner/claude-runner.js`:

```javascript
#!/usr/bin/env node
'use strict';

const { spawn, execFileSync } = require('child_process');
const readline = require('readline');
const path = require('path');

// --- Argument parsing ---

function parseArgs(argv) {
  const args = {
    prompt: null,
    resume: null,
    cwd: process.cwd(),
    model: 'sonnet',
    maxTurns: 100,
    maxBudget: null,
    systemPrompt: null,
    allowedTools: null,
    timeout: null,
  };

  for (let i = 2; i < argv.length; i++) {
    switch (argv[i]) {
      case '--prompt': args.prompt = argv[++i]; break;
      case '--resume': args.resume = argv[++i]; break;
      case '--cwd': args.cwd = path.resolve(argv[++i]); break;
      case '--model': args.model = argv[++i]; break;
      case '--max-turns': args.maxTurns = parseInt(argv[++i], 10); break;
      case '--max-budget': args.maxBudget = parseFloat(argv[++i]); break;
      case '--system-prompt': args.systemPrompt = argv[++i]; break;
      case '--allowed-tools': args.allowedTools = argv[++i]; break;
      case '--timeout': args.timeout = parseInt(argv[++i], 10); break;
      default:
        console.error(`Unknown argument: ${argv[i]}`);
        process.exit(1);
    }
  }

  if (!args.prompt && !args.resume) {
    console.error('Error: --prompt or --resume is required');
    process.exit(1);
  }

  return args;
}

// --- Timestamp helper ---

function ts() {
  return new Date().toLocaleTimeString('en-US', { hour12: false });
}

// --- Build claude -p command args ---

function buildClaudeArgs(args) {
  const claudeArgs = ['-p'];

  if (args.prompt) {
    claudeArgs.push(args.prompt);
  }

  claudeArgs.push('--output-format', 'stream-json');
  claudeArgs.push('--verbose');
  claudeArgs.push('--model', args.model);
  claudeArgs.push('--max-turns', String(args.maxTurns));

  if (args.resume) {
    claudeArgs.push('--resume', args.resume);
  }

  if (args.maxBudget) {
    claudeArgs.push('--max-budget-usd', String(args.maxBudget));
  }

  if (args.systemPrompt) {
    claudeArgs.push('--append-system-prompt', args.systemPrompt);
  }

  if (args.allowedTools) {
    for (const tool of args.allowedTools.split(',')) {
      claudeArgs.push('--allowedTools', tool.trim());
    }
  }

  claudeArgs.push('--dangerously-skip-permissions');

  return claudeArgs;
}

// --- Git helpers ---

function gitHead(cwd) {
  try {
    return execFileSync('git', ['rev-parse', 'HEAD'], { cwd, encoding: 'utf8' }).trim();
  } catch {
    return null;
  }
}

function gitLog(startSha, endSha, cwd) {
  try {
    const out = execFileSync('git', ['log', '--oneline', `${startSha}..${endSha}`], { cwd, encoding: 'utf8' }).trim();
    return out ? out.split('\n') : [];
  } catch {
    return [];
  }
}

function gitDiffStat(startSha, cwd) {
  try {
    const out = execFileSync('git', ['diff', '--stat', `${startSha}..HEAD`], { cwd, encoding: 'utf8' }).trim();
    const lines = out.split('\n');
    const summary = lines[lines.length - 1] || '';
    const filesMatch = summary.match(/(\d+) files? changed/);
    const insertMatch = summary.match(/(\d+) insertions?/);
    const deleteMatch = summary.match(/(\d+) deletions?/);
    return {
      changed_files: filesMatch ? parseInt(filesMatch[1], 10) : 0,
      insertions: insertMatch ? parseInt(insertMatch[1], 10) : 0,
      deletions: deleteMatch ? parseInt(deleteMatch[1], 10) : 0,
    };
  } catch {
    return { changed_files: 0, insertions: 0, deletions: 0 };
  }
}

function gitUncommittedCount(cwd) {
  try {
    const out = execFileSync('git', ['status', '--porcelain'], { cwd, encoding: 'utf8' }).trim();
    return out ? out.split('\n').length : 0;
  } catch {
    return 0;
  }
}

// --- Stream event filtering ---

function formatToolUse(content) {
  if (!content || !content.name) return null;

  const name = content.name;
  const input = content.input || {};

  switch (name) {
    case 'Read': return `Read: ${input.file_path || 'unknown'}`;
    case 'Edit': return `Edit: ${input.file_path || 'unknown'}`;
    case 'Write': return `Write: ${input.file_path || 'unknown'}`;
    case 'Bash': {
      const cmd = (input.command || '').slice(0, 80);
      return `Bash: ${cmd}${(input.command || '').length > 80 ? '...' : ''}`;
    }
    case 'Grep': return `Search: ${input.pattern || 'unknown'}`;
    case 'Glob': return `Search: ${input.pattern || 'unknown'}`;
    case 'Task': return `Subagent: ${(input.description || 'task').slice(0, 60)}`;
    default: return `${name}: ${JSON.stringify(input).slice(0, 60)}`;
  }
}

// --- Main ---

async function main() {
  const args = parseArgs(process.argv);
  const startTime = Date.now();
  const startSha = gitHead(args.cwd);

  // State tracking
  let sessionId = null;
  let modelName = null;
  let toolCalls = 0;
  let errors = [];
  let resultData = null;
  let stderrChunks = [];
  let killed = false;
  let incomplete = true;

  // Print startup banner
  console.log(`[${ts()}] Session starting...`);
  console.log(`           model: ${args.model} | max-turns: ${args.maxTurns} | max-budget: ${args.maxBudget || 'disabled'} | timeout: ${args.timeout || 'disabled'}`);
  if (args.resume) console.log(`           resuming: ${args.resume}`);

  // Spawn claude -p
  const claudeArgs = buildClaudeArgs(args);
  const env = { ...process.env };
  delete env.CLAUDECODE;

  const child = spawn('claude', claudeArgs, {
    cwd: args.cwd,
    env,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  // Timeout handling
  let timeoutId = null;
  if (args.timeout) {
    timeoutId = setTimeout(() => {
      killed = true;
      child.kill('SIGTERM');
      console.log(`[${ts()}] Timeout: killed after ${args.timeout}s`);
    }, args.timeout * 1000);
  }

  // Collect stderr
  child.stderr.on('data', (chunk) => {
    stderrChunks.push(chunk.toString());
  });

  // Process stream-json line by line
  const rl = readline.createInterface({ input: child.stdout });

  rl.on('line', (line) => {
    let event;
    try {
      event = JSON.parse(line);
    } catch {
      return; // skip non-JSON lines
    }

    // Extract session_id
    if (event.session_id && !sessionId) {
      sessionId = event.session_id;
      console.log(`[${ts()}] Session: ${sessionId}`);
    }

    // Handle event types
    if (event.type === 'assistant' && event.message) {
      const msg = event.message;

      // Extract model
      if (msg.model && !modelName) {
        modelName = msg.model;
      }

      // Process content blocks
      if (Array.isArray(msg.content)) {
        for (const block of msg.content) {
          if (block.type === 'tool_use') {
            toolCalls++;
            const formatted = formatToolUse(block);
            if (formatted) {
              console.log(`[${ts()}] ${formatted}`);

              // Detect git commits in Bash commands
              if (block.name === 'Bash' && block.input && block.input.command) {
                const cmd = block.input.command;
                if (cmd.includes('git commit')) {
                  const msgMatch = cmd.match(/-m\s+["']([^"']+)["']/);
                  if (msgMatch) {
                    console.log(`[${ts()}] Commit: ${msgMatch[1]}`);
                  }
                }
              }
            }
          } else if (block.type === 'text' && block.text) {
            // Only print substantial text (not partial streaming)
            const text = block.text.trim();
            if (text.length > 20) {
              console.log(`[${ts()}] Text: ${text.slice(0, 200)}${text.length > 200 ? '...' : ''}`);
            }
          }
        }
      }
    }

    // Capture result event
    if (event.type === 'result') {
      resultData = event;
      incomplete = false;
    }
  });

  // Wait for process to exit
  const exitCode = await new Promise((resolve) => {
    child.on('close', (code) => {
      if (timeoutId) clearTimeout(timeoutId);
      resolve(code || 0);
    });
  });

  // --- Build summary ---

  const endTime = Date.now();
  const endSha = gitHead(args.cwd);

  // Token/cost data from result
  let tokens = { input: 0, output: 0, cache_read: 0, cache_creation: 0, context_window: 200000, context_used_pct: 0 };
  let costUsd = 0;

  if (resultData) {
    if (resultData.usage) {
      tokens.input = resultData.usage.input_tokens || 0;
      tokens.output = resultData.usage.output_tokens || 0;
      tokens.cache_read = resultData.usage.cache_read_input_tokens || 0;
      tokens.cache_creation = resultData.usage.cache_creation_input_tokens || 0;
    }
    costUsd = resultData.total_cost_usd || 0;
    sessionId = sessionId || resultData.session_id;

    // Extract context window from modelUsage
    if (resultData.modelUsage) {
      const models = Object.values(resultData.modelUsage);
      if (models.length > 0) {
        tokens.context_window = models[0].contextWindow || 200000;
        modelName = modelName || Object.keys(resultData.modelUsage)[0];
      }
    }
  }

  const totalTokens = tokens.input + tokens.output + tokens.cache_read + tokens.cache_creation;
  tokens.context_used_pct = tokens.context_window > 0
    ? Math.round((totalTokens / tokens.context_window) * 100)
    : 0;

  // Git summary
  const git = {
    start_sha: startSha ? startSha.slice(0, 7) : null,
    end_sha: endSha ? endSha.slice(0, 7) : null,
    commits: [],
    changed_files: 0,
    insertions: 0,
    deletions: 0,
    uncommitted_changes: 0,
  };

  if (startSha && endSha) {
    if (startSha !== endSha) {
      git.commits = gitLog(startSha, endSha, args.cwd);
      const stat = gitDiffStat(startSha, args.cwd);
      git.changed_files = stat.changed_files;
      git.insertions = stat.insertions;
      git.deletions = stat.deletions;
    }
    git.uncommitted_changes = gitUncommittedCount(args.cwd);
  }

  // Collect errors
  if (exitCode !== 0 && stderrChunks.length > 0) {
    errors.push(stderrChunks.join('').trim().slice(0, 500));
  }

  const contextWarning = tokens.context_used_pct > 60;

  const summary = {
    session_id: sessionId,
    model: modelName || args.model,
    exit_code: killed ? -1 : exitCode,
    duration_seconds: Math.round((endTime - startTime) / 1000),
    cost_usd: costUsd,
    tokens,
    tool_calls: toolCalls,
    git,
    errors,
    context_warning: contextWarning,
    ...(incomplete && { incomplete: true }),
    ...(killed && { killed: true }),
    resume_command: sessionId
      ? `node ${path.resolve(__filename)} --resume ${sessionId} --prompt "Continue from where you left off"`
      : null,
  };

  // Print summary
  console.log('');
  console.log(`[${ts()}] Done. ${toolCalls} tool calls, ${git.commits.length} commits, ${totalTokens} tokens, $${costUsd.toFixed(2)}, ${summary.duration_seconds}s`);
  if (contextWarning) {
    console.log(`[${ts()}] WARNING: Context usage at ${tokens.context_used_pct}% — consider starting a new session for next batch`);
  }
  console.log('');
  console.log('---CLAUDE-RUNNER-RESULT---');
  console.log(JSON.stringify(summary, null, 2));
}

main().catch((err) => {
  console.error(`Fatal: ${err.message}`);
  console.log('---CLAUDE-RUNNER-RESULT---');
  console.log(JSON.stringify({
    session_id: null,
    model: null,
    exit_code: 1,
    duration_seconds: 0,
    cost_usd: 0,
    tokens: { input: 0, output: 0, cache_read: 0, cache_creation: 0, context_window: 0, context_used_pct: 0 },
    tool_calls: 0,
    git: { start_sha: null, end_sha: null, commits: [], changed_files: 0, insertions: 0, deletions: 0, uncommitted_changes: 0 },
    errors: [err.message],
    context_warning: false,
    resume_command: null,
  }, null, 2));
  process.exit(1);
});
```

**Step 2: Make the script executable**

Run: `chmod +x superpowers/skills/headless-runner/claude-runner.js`

**Step 3: Verify the script parses args correctly**

Run: `node superpowers/skills/headless-runner/claude-runner.js 2>&1 || true`
Expected: `Error: --prompt or --resume is required`

Run: `node superpowers/skills/headless-runner/claude-runner.js --prompt "test" --model opus --max-turns 50 --cwd /tmp 2>&1 | head -3`
Expected: Lines showing session starting with model: opus, max-turns: 50 (will fail to connect but args parse correctly)

**Step 4: Commit**

```bash
git add superpowers/skills/headless-runner/claude-runner.js
git commit -m "feat(superpowers): add claude-runner.js headless session wrapper"
```

---

### Task 2: Create SKILL.md for headless-runner

**Files:**
- Create: `superpowers/skills/headless-runner/SKILL.md`

**Step 1: Write the skill definition**

Create `superpowers/skills/headless-runner/SKILL.md`:

```markdown
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
    "context_used_pct": 51
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
```

**Step 2: Commit**

```bash
git add superpowers/skills/headless-runner/SKILL.md
git commit -m "feat(superpowers): add headless-runner skill definition"
```

---

### Task 3: Update writing-plans to offer 3rd execution option

**Files:**
- Modify: `superpowers/skills/writing-plans/SKILL.md:97-117`

**Step 1: Update the Execution Handoff section**

Replace the entire `## Execution Handoff` section (lines 97-117) with:

```markdown
## Execution Handoff

After saving the plan, offer execution choice:

**"Plan complete and saved to `docs/plans/<filename>.md`. Three execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**3. Headless Runner (background)** - I launch claude -p in background, minimal context cost, auto context awareness, structured results back

**Which approach?"**

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development
- Stay in this session
- Fresh subagent per task + code review

**If Parallel Session chosen:**
- Guide them to open new session in worktree
- **REQUIRED SUB-SKILL:** New session uses superpowers:executing-plans

**If Headless Runner chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:headless-runner
- Dispatch tasks via claude-runner.js using Bash tool with run_in_background
- Check context_warning after each batch to decide resume vs new session
- When all batches complete, use superpowers:finishing-a-development-branch
```

**Step 2: Verify the file is valid markdown**

Run: `head -5 superpowers/skills/writing-plans/SKILL.md && echo "---" && tail -20 superpowers/skills/writing-plans/SKILL.md`
Expected: Frontmatter intact at top, new 3-option handoff section at bottom

**Step 3: Commit**

```bash
git add superpowers/skills/writing-plans/SKILL.md
git commit -m "feat(superpowers): add headless runner as 3rd execution option in writing-plans"
```

---

### Task 4: Test claude-runner.js with a real session

**Step 1: Run a simple test session**

Run:
```bash
CLAUDECODE= node superpowers/skills/headless-runner/claude-runner.js \
  --prompt "List the files in the current directory using ls, then say done." \
  --cwd /home/cp/code/dkmaker/my-claude-plugins \
  --model sonnet \
  --max-turns 5
```

Expected output pattern:
```
[HH:MM:SS] Session starting...
           model: sonnet | max-turns: 5 | max-budget: disabled | timeout: disabled
[HH:MM:SS] Session: <uuid>
[HH:MM:SS] Bash: ls
[HH:MM:SS] Text: ...
[HH:MM:SS] Done. N tool calls, 0 commits, NNNN tokens, $N.NN, Ns

---CLAUDE-RUNNER-RESULT---
{ valid JSON with all fields }
```

**Step 2: Verify JSON summary is valid**

Run:
```bash
CLAUDECODE= node superpowers/skills/headless-runner/claude-runner.js \
  --prompt "Say hello" \
  --model haiku \
  --max-turns 3 2>&1 | sed -n '/---CLAUDE-RUNNER-RESULT---/,$ p' | tail -n +2 | jq '.session_id, .model, .exit_code, .tokens.context_used_pct'
```

Expected: 4 lines — session_id string, model string, 0, and a number

**Step 3: Test resume capability**

Capture session ID from step 1, then:
```bash
SESSION_ID=<from step 1>
CLAUDECODE= node superpowers/skills/headless-runner/claude-runner.js \
  --resume $SESSION_ID \
  --prompt "What files did you see in the previous turn?" \
  --max-turns 3
```

Expected: Session resumes, references previous context

**Step 4: Test error handling (bad model)**

Run:
```bash
CLAUDECODE= node superpowers/skills/headless-runner/claude-runner.js \
  --prompt "test" \
  --model nonexistent 2>&1 | tail -5
```

Expected: JSON summary with exit_code != 0 and errors array populated

**Step 5: Test timeout**

Run:
```bash
CLAUDECODE= node superpowers/skills/headless-runner/claude-runner.js \
  --prompt "Read every file in this repository one by one" \
  --max-turns 50 \
  --timeout 10 2>&1 | tail -10
```

Expected: Killed after 10 seconds, JSON summary with `killed: true`

---

### Task 5: Bump plugin version and commit

**Files:**
- Modify: `superpowers/.claude-plugin/plugin.json:4`

**Step 1: Bump version**

Change version from `"4.3.1"` to `"4.4.0"` (new feature = minor bump).

**Step 2: Commit**

```bash
git add superpowers/.claude-plugin/plugin.json
git commit -m "feat(superpowers): bump to 4.4.0 for headless-runner feature"
```
