---
name: dev
description: Development toolkit for the my-claude-plugins marketplace. Use when working on plugin development, troubleshooting plugin issues, creating new plugins, or maintaining the my-claude-plugins repository.
argument-hint: "[develop|troubleshoot|scaffold] [plugin-name]"
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Bash(git:*), Bash(claude:*)
---

# my-plugin-dev: Development Toolkit

Development toolkit for the **my-claude-plugins** marketplace repository (`dkmaker/my-claude-plugins`).

## Step 1: Auto-Detect Context

Before doing anything, gather context:

### Detect Repository

Check if we're inside the my-claude-plugins repo:

```bash
# Check for marketplace.json with our known plugins
if [ -f ".claude-plugin/marketplace.json" ]; then
  jq -r '.name' .claude-plugin/marketplace.json
fi
```

If not in the repo, check common locations:
- `/home/cp/code/dkmaker/my-claude-plugins`

If repo not found, ask the user for the path.

### Detect Dev vs Production Mode

Check how plugins are loaded:
- **Dev mode**: Plugins loaded via `--plugin-dir` pointing to the repo source
- **Production mode**: Plugins loaded from cache at `~/.claude/plugins/cache/my-claude-plugins/`

If production mode is detected, warn:
> **You're running with cached plugins.** Changes to source files won't take effect.
> To develop locally, restart Claude Code with:
> ```
> claude --plugin-dir /home/cp/code/dkmaker/my-claude-plugins/<plugin-name>
> ```

### Gather Status

```bash
# Current branch and dirty state
git status --short --branch
# Which plugins have changes
git diff --name-only | grep -oP '^[^/]+' | sort -u
```

Present a context summary to the user before proceeding.

## Step 2: Documentation Source

This skill depends on `claude-docs` CLI as the source of truth for Claude Code conventions.

**Priority chain:**

1. **Check for claude-docs**: Run `command -v claude-docs`
   - If available, use `claude-docs get <slug>` before generating any plugin component
   - Key slugs: `plugins`, `plugins-reference`, `skills`, `hooks-guide`, `hooks`, `mcp`, `plugin-marketplaces`
   - Run `claude-docs list` to discover all available topics

2. **If claude-docs not found**: Ask the user to enable the claude-expert plugin:
   > The `claude-expert` plugin provides the `claude-docs` CLI which is the source of truth for Claude Code documentation.
   > Enable it with: `/plugin install claude-expert@my-claude-plugins`

3. **Last resort fallback**: If user declines claude-expert, fetch documentation directly:
   - Documentation index: `https://code.claude.com/docs/llms.txt`
   - Use WebFetch to pull the index, then fetch specific page URLs from it
   - Warn: "Using remote docs — install claude-expert for faster, cached access"

**IMPORTANT**: Before generating any plugin component (hooks, skills, MCP config, plugin.json), ALWAYS verify the current format via this documentation chain. Never rely on training data for Claude Code specifics.

## Step 3: Route to Workflow

Based on `$ARGUMENTS`:

| First argument | Action |
|----------------|--------|
| `develop` | Load [workflows/develop.md](workflows/develop.md) — full dev lifecycle |
| `troubleshoot` | Load [workflows/troubleshoot.md](workflows/troubleshoot.md) — diagnostics & debugging |
| `scaffold` | Load [workflows/scaffold.md](workflows/scaffold.md) — create a new plugin |
| *(none)* | Show the three options below and ask which workflow |

If no argument provided, present:

1. **develop** — Make changes to an existing plugin (branch, edit, test, validate, PR)
2. **troubleshoot** — Debug why a plugin/hook/skill/MCP isn't working
3. **scaffold** — Create a brand new plugin from scratch

Also show:
- Current branch and dirty files
- Whether in dev or production mode
- Which plugins have uncommitted changes
- The `claude` command line for local dev testing

## Reference Files

- [reference/repo-map.md](reference/repo-map.md) — Complete inventory of all plugins, their components, and file paths
- [reference/plugin-templates.md](reference/plugin-templates.md) — Boilerplate templates for every plugin type

Load `repo-map.md` when you need to understand the current state of any plugin.
Load `plugin-templates.md` when creating or modifying plugin components.
