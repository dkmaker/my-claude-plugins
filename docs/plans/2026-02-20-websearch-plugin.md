# Websearch Plugin Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a `websearch` plugin with a single skill that auto-detects research area and loads the relevant supporting file. Replaces the Perplexity MCP plugin.

**Architecture:** One skill (`websearch`) with SKILL.md as the router and 7 supporting files for specific areas. Claude auto-detects which area applies based on conversation context, loads the relevant supporting file, then executes the search. The `websearch` CLI binary at `/home/cp/code/dkmaker/websearch-cli/websearch` is the search backend.

**Tech Stack:** Bash (websearch CLI), Markdown (SKILL.md + supporting files)

---

### Task 1: Create plugin structure and metadata

**Status:** DONE (commit 8dc25f1) — plugin.json and marketplace.json already created.

Need to clean up: remove the 7 separate skill directories created by mistake, create single skill directory.

**Step 1: Remove wrong directories, create correct structure**

```bash
rm -rf websearch/skills/{search,debug,docs,patterns,bootstrap,deps,explore}
mkdir -p websearch/skills/websearch
```

**Step 2: Commit**

```bash
git add -A
git commit -m "refactor(websearch): single skill with supporting files"
```

---

### Task 2: Create SessionStart hook

**Files:**
- Create: `websearch/hooks/hooks.json`
- Create: `websearch/hooks/scripts/check-websearch.sh`

**Step 1: Create hooks.json**

```json
{
  "hooks": [
    {
      "event": "SessionStart",
      "command": "bash websearch/hooks/scripts/check-websearch.sh",
      "timeout": 10000
    }
  ]
}
```

**Step 2: Create check-websearch.sh**

The binary is at `/home/cp/code/dkmaker/websearch-cli/websearch` — check PATH first, fall back to direct path.

```bash
#!/usr/bin/env bash
set -euo pipefail

WEBSEARCH_BIN=""
if command -v websearch &>/dev/null; then
  WEBSEARCH_BIN="websearch"
elif [ -x "$HOME/code/dkmaker/websearch-cli/websearch" ]; then
  WEBSEARCH_BIN="$HOME/code/dkmaker/websearch-cli/websearch"
fi

if [ -n "$WEBSEARCH_BIN" ]; then
  HELP=$("$WEBSEARCH_BIN" 2>&1 | head -8)
  STATUS="websearch CLI ready"
  CONTEXT="# Websearch CLI Available

The \`websearch\` CLI is ready (binary: ${WEBSEARCH_BIN}).
Use /websearch for web search and developer research.

${HELP}"
else
  STATUS="WARNING: websearch CLI not found"
  CONTEXT="# Websearch CLI Not Found

The websearch CLI binary was not found on PATH or at ~/code/dkmaker/websearch-cli/websearch.
The /websearch skill will not work without it."
fi

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $(printf '%s' "$CONTEXT" | jq -Rs .)
  },
  "systemMessage": $(printf '%s' "$STATUS" | jq -Rs .)
}
EOF
```

**Step 3: chmod +x and test**

```bash
chmod +x websearch/hooks/scripts/check-websearch.sh
bash websearch/hooks/scripts/check-websearch.sh | jq .
```

**Step 4: Commit**

```bash
git add websearch/hooks/
git commit -m "feat(websearch): add SessionStart hook to validate CLI"
```

---

### Task 3: Create SKILL.md (main router)

**Files:**
- Create: `websearch/skills/websearch/SKILL.md`

The SKILL.md is the entry point. It describes ALL areas so Claude's auto-detection works, then instructs Claude to read the relevant supporting file.

```yaml
---
name: websearch
description: >
  Web search and developer research. Use for ANY of these:
  searching the web, looking up documentation, debugging errors/crashes/issues,
  researching best practices and design patterns, finding project templates and
  setup guides, resolving dependency conflicts, or exploring GitHub repositories
  and code. Handles both general web queries and development-specific research.
allowed-tools: Bash(websearch *), Bash(~/code/dkmaker/websearch-cli/websearch *), Read
---

# Websearch — Web Search & Developer Research

Search the web and research development topics using the `websearch` CLI.

## Determine the research area

Based on the user's request, identify which area applies:

| Area | When to use | Supporting file |
|------|------------|-----------------|
| Debugging | Error messages, stack traces, crashes, deadlocks, performance issues | [debug.md](debug.md) |
| Documentation | Library/API docs, usage examples, configuration references | [docs.md](docs.md) |
| Patterns | Best practices, design patterns, architecture decisions, conventions | [patterns.md](patterns.md) |
| Bootstrapping | Project templates, starter configs, initial setup, scaffolding | [bootstrap.md](bootstrap.md) |
| Dependencies | Version conflicts, migrations, breaking changes, compatibility | [deps.md](deps.md) |
| Exploration | GitHub repos, code search, finding implementations | [explore.md](explore.md) |
| General | Everything else — news, facts, general questions | [search.md](search.md) |

**Read the matching supporting file** for specific commands and strategies, then execute the search.

## Quick reference

```bash
# The websearch binary (use whichever is available)
websearch "query"
~/code/dkmaker/websearch-cli/websearch "query"

# Key flags
-m <mode>        # ask (default), search, reason, research
-p <profile>     # general (default), github, nodejs, python
--provider <p>   # perplexity (default), brave, github
--include-sources # include citation URLs
--no-cache       # bypass 60m cache
--json           # JSON output
```

## Arguments

$ARGUMENTS
```

**Step 2: Commit**

```bash
git add websearch/skills/websearch/SKILL.md
git commit -m "feat(websearch): add main skill with area routing"
```

---

### Task 4: Create supporting files (all 7)

**Files:**
- Create: `websearch/skills/websearch/search.md`
- Create: `websearch/skills/websearch/debug.md`
- Create: `websearch/skills/websearch/docs.md`
- Create: `websearch/skills/websearch/patterns.md`
- Create: `websearch/skills/websearch/bootstrap.md`
- Create: `websearch/skills/websearch/deps.md`
- Create: `websearch/skills/websearch/explore.md`

Each file contains area-specific strategies, commands, and guidelines. Content is identical to what was in the original plan's individual SKILL.md files but without frontmatter (these are supporting files, not skills).

**search.md:**

```markdown
# General Web Search

## Commands

```bash
# Quick answer (default mode: ask)
websearch "your question here"

# Deep research (slower, more thorough)
websearch -m research "complex topic"

# Reasoning with chain-of-thought
websearch -m reason "question requiring analysis"

# Search for links/results only
websearch -m search "topic"

# Brave web search (alternative provider)
websearch --provider brave "query"
```

## Guidelines

- `-m ask` (default) for quick factual questions
- `-m reason` when the answer requires analysis or comparison
- `-m research` for comprehensive deep-dive topics (slow, 30s+)
- `-m search` when you need URLs/links rather than synthesized answers
- `--include-sources` when citations matter
- `--no-cache` for time-sensitive queries
```

**debug.md:**

```markdown
# Debug Research

## Strategy

1. **Error messages**: Search the exact error message or key phrases
2. **Stack traces**: Extract the root cause line and search for it
3. **Runtime issues**: Describe the symptom (deadlock, memory leak, crash)
4. **GitHub issues**: Search for known bugs in the relevant project

## Commands

```bash
# Reason through a debugging problem (recommended)
websearch -m reason "why does X happen when Y"

# Search GitHub issues for known bugs
websearch -p github -m issues "error message or symptom"

# Language-specific profiles
websearch -p nodejs "node error message"
websearch -p python "python traceback explanation"

# Find code examples showing the fix
websearch -p github -m code "fix for specific pattern"
```

## Guidelines

- Use `-m reason` for debugging — chain-of-thought analysis
- Use `-p github -m issues` to find if others hit the same bug
- Include language/framework name in queries
- Quote exact error messages for best results
- Add `--gh-state open` or `--gh-repo owner/repo` to narrow GitHub results
```

**docs.md:**

```markdown
# Documentation Lookup

## Commands

```bash
# Quick documentation lookup (default)
websearch "how to use X in Y"

# Node.js ecosystem (filters to nodejs.org, MDN, npmjs.com)
websearch -p nodejs "express middleware setup"

# Python ecosystem (filters to docs.python.org, pypi.org, realpython.com)
websearch -p python "sqlalchemy async session"

# Find official docs via reasoning
websearch -m reason "correct way to configure X in Y"

# Find GitHub README/docs for a library
websearch -p github "library-name"
```

## Guidelines

- Use `-p nodejs` or `-p python` for ecosystem-specific queries — filters to authoritative sources
- Use `-m reason` for "how should I configure X" questions needing analysis
- Use `-p github` to find a library's repo and README
- Default `-m ask` works well for straightforward "how to use X" questions
- `--include-sources` when you need to cite documentation URLs
```

**patterns.md:**

```markdown
# Patterns & Best Practices

## Commands

```bash
# Analyze tradeoffs between approaches (recommended)
websearch -m reason "tradeoffs between X vs Y for Z"

# Deep research on architecture patterns
websearch -m research "best practices for X architecture"

# Find real-world implementations
websearch -p github "pattern-name implementation language"

# Find community consensus
websearch "recommended approach for X"
```

## Guidelines

- `-m reason` for comparison/tradeoff questions — structured analysis
- `-m research` for comprehensive overviews of a pattern (slow)
- `-p github` to find real implementations demonstrating a pattern
- Frame queries as tradeoff questions: "X vs Y" or "when to use X over Y"
```

**bootstrap.md:**

```markdown
# Project Bootstrapping

## Commands

```bash
# Find GitHub project templates and starters
websearch -p github "template starter language/framework"

# Filter by language and quality
websearch -p github --gh-language go --gh-stars '>100' "project template"

# Find scaffolding tools
websearch -p github --gh-topic template "framework-name starter"

# Setup/configuration guides
websearch -m reason "how to set up X from scratch with Y"

# Official getting-started docs
websearch -p nodejs "create-react-app alternative"
websearch -p python "python project setup pyproject.toml"
```

## Guidelines

- `-p github` with `--gh-stars` and `--gh-language` for quality templates
- `-m reason` for "how to set up X" step-by-step guidance
- `--gh-topic template` or `--gh-topic starter` for template repos
- `--gh-pushed` to filter for recently maintained templates
```

**deps.md:**

```markdown
# Dependency Management

## Commands

```bash
# GitHub issues for dependency conflicts
websearch -p github -m issues "package-name version conflict error"

# Search in a specific repo's issues
websearch -p github -m issues --gh-repo owner/repo "breaking change"

# Migration/upgrade paths
websearch -m reason "how to migrate from X v1 to v2"

# Check compatibility
websearch -m reason "is package-A compatible with package-B version X"

# Find changelogs and breaking changes
websearch -p github -m code --gh-filename CHANGELOG "package-name breaking"
```

## Guidelines

- `-p github -m issues` for real reports of dependency conflicts
- `--gh-repo` to search within a specific project's issues
- `-m reason` for migration path analysis
- `--gh-state open` for unresolved, `--gh-state closed` for solved
- Include version numbers for specificity
```

**explore.md:**

```markdown
# GitHub Code & Repo Exploration

## Commands

```bash
# Search for repositories
websearch -p github "description of what you're looking for"

# Filter by language and quality
websearch -p github --gh-language typescript --gh-stars '>500' "state management"

# Search code across GitHub
websearch -p github -m code "specific function or pattern"

# Search code in specific file types
websearch -p github -m code --gh-extension go "pattern to find"

# Search within a specific repo
websearch -p github -m code --gh-repo owner/repo "function name"

# Find repos by topic
websearch -p github --gh-topic cli --gh-language rust "search tool"

# Recently active projects
websearch -p github --gh-pushed '>2025-01-01' --gh-stars '>100' "topic"
```

## Guidelines

- Default mode (`repos`) to find repositories
- `-m code` to search actual source code across GitHub
- Combine `--gh-language`, `--gh-stars`, `--gh-topic` for precise filtering
- `--gh-sort stars` for most popular results
- `--gh-pushed` for actively maintained projects
```

**Step 2: Commit**

```bash
git add websearch/skills/websearch/
git commit -m "feat(websearch): add supporting files for all research areas"
```

---

### Task 5: Create README and finalize

**Files:**
- Create: `websearch/README.md`

**Step 1: Create README**

```markdown
# Websearch Plugin

Web search and developer research plugin for Claude Code, powered by the [`websearch` CLI](https://github.com/dkmaker/websearch-cli).

## Usage

Invoke with `/websearch <query>` or let Claude auto-detect when web search is needed.

Claude automatically determines the research area and loads the appropriate strategy:

- **Debugging** — errors, crashes, stack traces, performance issues
- **Documentation** — library/API docs, usage examples, configuration
- **Patterns** — best practices, design patterns, architecture decisions
- **Bootstrapping** — project templates, starter configs, setup guides
- **Dependencies** — version conflicts, migrations, breaking changes
- **Exploration** — GitHub repos, code search, implementations
- **General** — news, facts, any other web search

## Requirements

- `websearch` CLI binary (on PATH or at `~/code/dkmaker/websearch-cli/websearch`)
- Provider API keys configured (see websearch CLI docs)

## Search Providers

- **Perplexity**: ask, search, reason, research modes
- **Brave**: web search
- **GitHub**: repos, code, issues search
```

**Step 2: Commit**

```bash
git add websearch/README.md
git commit -m "docs(websearch): add plugin README"
```

---

### Task 6: Validate and test

**Step 1: Validate structure**

```bash
find websearch/ -type f | sort
```

Expected:
```
websearch/.claude-plugin/plugin.json
websearch/README.md
websearch/hooks/hooks.json
websearch/hooks/scripts/check-websearch.sh
websearch/skills/websearch/SKILL.md
websearch/skills/websearch/bootstrap.md
websearch/skills/websearch/debug.md
websearch/skills/websearch/deps.md
websearch/skills/websearch/docs.md
websearch/skills/websearch/explore.md
websearch/skills/websearch/patterns.md
websearch/skills/websearch/search.md
```

**Step 2: Validate hook**

```bash
bash websearch/hooks/scripts/check-websearch.sh | jq .
```

**Step 3: Validate JSON files**

```bash
jq . websearch/.claude-plugin/plugin.json
jq . websearch/hooks/hooks.json
jq . .claude-plugin/marketplace.json
```

**Step 4: Test websearch CLI**

```bash
~/code/dkmaker/websearch-cli/websearch "test query"
```

**Step 5: Final commit if fixes needed**

```bash
git add -A && git commit -m "fix(websearch): validation fixes"
```
