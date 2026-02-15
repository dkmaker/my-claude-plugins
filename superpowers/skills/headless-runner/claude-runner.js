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
