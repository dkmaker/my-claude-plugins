# Design: my-plugin-dev Plugin

**Date**: 2026-02-15
**Author**: Christian Pedersen
**Status**: Approved

## Overview

A dedicated plugin for the my-claude-plugins marketplace repository that provides a development toolkit for maintaining, developing, troubleshooting, and scaffolding plugins. It solves the core pain point of developing plugins that are installed from a marketplace cache — edits to source files don't take effect until reinstalled. The skill auto-detects context and generates the correct `--plugin-dir` commands for local development.

## Plugin Structure

```
my-plugin-dev/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── dev/
│       ├── SKILL.md                    # Main entry point + auto-detection + router
│       ├── workflows/
│       │   ├── develop.md              # Full dev lifecycle flow
│       │   ├── troubleshoot.md         # Debugging & diagnostics
│       │   └── scaffold.md             # New plugin creation
│       └── reference/
│           ├── repo-map.md             # Complete inventory of all plugins & components
│           └── plugin-templates.md     # Boilerplate templates for all plugin types
└── README.md
```

## Plugin Manifest

**`.claude-plugin/plugin.json`**:

```json
{
  "name": "my-plugin-dev",
  "description": "Development toolkit for the my-claude-plugins marketplace repository",
  "version": "1.0.0",
  "author": {
    "name": "Christian Pedersen",
    "email": "christian@dkmaker.xyz"
  }
}
```

**Marketplace entry** (added to root `.claude-plugin/marketplace.json`):

```json
{
  "name": "my-plugin-dev",
  "source": "./my-plugin-dev",
  "description": "Development toolkit for maintaining and developing the my-claude-plugins marketplace",
  "version": "1.0.0",
  "keywords": ["development", "plugin-dev", "toolkit", "maintenance"],
  "category": "development"
}
```

## SKILL.md — Main Entry Point

### Frontmatter

```yaml
---
name: dev
description: Development toolkit for the my-claude-plugins marketplace. Use when working on plugin development, troubleshooting plugin issues, creating new plugins, or maintaining the my-claude-plugins repository.
argument-hint: [develop|troubleshoot|scaffold] [plugin-name]
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Bash(git:*), Bash(claude:*)
---
```

### Auto-Detection Logic

1. **Detect repo location**: Check if CWD is inside the `my-claude-plugins` repo (look for `.claude-plugin/marketplace.json` with known plugin dirs).
2. **Detect dev vs production mode**: Check if any `--plugin-dir` flags point to local paths (vs cache at `~/.claude/plugins/cache/`). If plugins are loaded from cache, warn that changes won't take effect and suggest restarting with `--plugin-dir`.
3. **Detect target plugin**: If `$ARGUMENTS` includes a plugin name, scope to that plugin. Otherwise, infer from CWD or ask.

### Routing

| Argument | Action |
|----------|--------|
| `develop` | Load `workflows/develop.md` — full dev lifecycle |
| `troubleshoot` | Load `workflows/troubleshoot.md` — diagnostics |
| `scaffold` | Load `workflows/scaffold.md` — new plugin creation |
| *(none or unclear)* | Present the three workflows and ask which one, show current context (repo status, branch, which plugins are modified) |

### Context Summary (always generated before routing)

- Current branch + dirty status
- Which plugins have uncommitted changes
- Whether running in dev mode or production mode
- The specific `claude` command line needed to test locally

## Documentation Dependency

The skill depends on the `claude-docs` CLI (provided by the `claude-expert` plugin) as the source of truth for all Claude Code documentation.

### Source Priority Chain

1. **Preferred: `claude-docs` CLI**
   - Check: `command -v claude-docs`
   - If available, use `claude-docs get <topic>` for any Claude Code questions
   - Key slugs per workflow:
     - **develop**: `plugins`, `plugins-reference`, `skills`, `hooks-guide`, `hooks`
     - **troubleshoot**: `troubleshooting`, `plugins-reference`, `hooks`, `mcp`, `settings`
     - **scaffold**: `plugins`, `plugins-reference`, `skills`, `hooks-guide`, `hooks`, `mcp`, `plugin-marketplaces`
   - Run `claude-docs list` to discover topics not in the above list

2. **Fallback: Ask user to enable claude-expert plugin**
   - If `claude-docs` not found, suggest: `/plugin install claude-expert@my-claude-plugins`

3. **Last resort: Fetch llms.txt directly**
   - Hardcoded URL: `https://code.claude.com/docs/llms.txt`
   - Use WebFetch to pull the documentation index, then specific pages
   - Warn: "Using remote docs — install claude-expert for faster, cached access"

### When Docs Are Consulted

Before generating any plugin component (hook, skill, MCP config, plugin.json), ALWAYS verify the current format via the docs chain. Never rely on training data for Claude Code specifics.

## Workflow: develop.md

Full dev lifecycle flow:

```
1. Sync & Branch
   ├── git fetch origin
   ├── If on main → create feature branch: feat/<plugin-name>-<description>
   └── If on feature branch → confirm it's up to date with main

2. Identify Target Plugin
   ├── From $ARGUMENTS[1] if provided
   ├── From CWD if inside a plugin directory
   └── Ask user to pick from inventory

3. Make Changes
   ├── Show current plugin structure (files, hooks, skills)
   ├── Reference repo-map.md for full context
   └── Apply changes following repo conventions

4. Local Testing
   ├── Generate the exact claude command:
   │   claude --plugin-dir /home/cp/code/dkmaker/my-claude-plugins/<plugin-name>
   ├── For multiple plugins under test:
   │   claude --plugin-dir ./plugin-a --plugin-dir ./plugin-b
   ├── Remind: restart Claude Code to pick up changes
   └── Suggest specific things to test based on what changed
       (hooks → check SessionStart output, skills → try /command, MCP → check /mcp)

5. Validate
   ├── JSON syntax check on all plugin.json, hooks.json, marketplace.json
   ├── Check hook scripts are executable (chmod +x)
   ├── Verify SKILL.md frontmatter is valid YAML
   ├── Ensure marketplace.json is updated if version changed
   └── Run: claude plugin validate <plugin-dir>

6. Update Repo Map
   ├── If any structural changes were made (new files, renamed skills,
   │   changed hooks, new MCP configs, version bumps):
   │   └── Regenerate reference/repo-map.md to reflect current state
   ├── Changes that trigger a repo-map update:
   │   ├── New or removed plugin directories
   │   ├── Added/removed/renamed skills or commands
   │   ├── Changed hook configurations
   │   ├── MCP server additions/removals
   │   ├── Version bumps in plugin.json or marketplace.json
   │   └── New scripts or supporting files
   └── Include repo-map changes in the same commit

7. Commit & PR
   ├── Stage only the changed plugin's files
   ├── Conventional commit: feat(<plugin>): / fix(<plugin>): / docs(<plugin>):
   ├── Push branch
   └── Create PR with summary of changes and testing instructions
```

## Workflow: troubleshoot.md

Diagnostic tree:

```
1. Identify the Problem
   ├── From $ARGUMENTS if provided
   └── Ask: What's not working?
       ├── Hook not running / wrong output
       ├── Skill not appearing / not triggering
       ├── MCP server not connecting
       ├── Plugin not loading at all
       └── Cache out of sync with source

2. Environment Check (always run first)
   ├── Confirm CWD and repo state (git status)
   ├── Check dev mode vs production mode
   ├── Compare cache vs source:
   │   diff <(ls ~/.claude/plugins/cache/my-claude-plugins/<plugin>/) \
   │        <(ls /home/cp/code/dkmaker/my-claude-plugins/<plugin>/)
   └── Check Claude Code version: claude --version

3. Plugin-Type Specific Diagnostics

   HOOKS:
   ├── Is hooks.json valid JSON? (jq . hooks/hooks.json)
   ├── Are scripts executable? (ls -la hooks/scripts/)
   ├── Does the script output valid hook JSON format?
   │   (run it manually and validate output with jq)
   ├── Check timeout — is the script too slow?
   ├── Test script in isolation: bash hooks/scripts/<script>.sh | jq .
   └── Check claude --debug output for hook loading errors

   SKILLS:
   ├── Is SKILL.md frontmatter valid YAML?
   ├── Is description populated? (required for auto-invocation)
   ├── Is disable-model-invocation accidentally true?
   ├── Check character budget: /context for truncation warnings
   ├── Is the skill directory in the right location?
   │   (skills/<name>/SKILL.md, NOT inside .claude-plugin/)
   └── Test manual invocation: /plugin-name:skill-name

   MCP SERVERS:
   ├── Is the MCP config valid JSON?
   ├── Are required env vars set? (check .claude/settings.local.json)
   ├── Can the command run? (npx -y <package> --help)
   ├── Check /mcp for connection status
   └── Check claude --debug for MCP initialization errors

   GENERAL LOADING:
   ├── Does .claude-plugin/plugin.json exist and parse?
   ├── Are components at plugin root (NOT inside .claude-plugin/)?
   ├── Is the plugin registered in marketplace.json?
   ├── Is the plugin enabled? Check settings:
   │   jq '.enabledPlugins' ~/.claude/settings.json
   └── Reinstall: /plugin uninstall <name> && /plugin install <name>

4. Resolution
   ├── Apply fix
   ├── If cache issue → provide reinstall command or suggest --plugin-dir
   ├── Verify fix works
   └── If structural changes → update repo-map.md
```

## Workflow: scaffold.md

New plugin creation flow:

```
1. Gather Requirements
   ├── Plugin name (kebab-case, validated)
   ├── Plugin type:
   │   ├── Feature plugin (hooks + skills + scripts)
   │   ├── MCP server wrapper (thin config around external MCP)
   │   └── Hybrid (MCP + custom skills/hooks)
   ├── Description (brief, for marketplace listing)
   ├── Category (knowledge, productivity, testing, creative, development)
   └── Components needed:
       ├── SessionStart hook?
       ├── Skills? (how many, names)
       ├── Commands?
       ├── MCP server config?
       └── Scripts?

2. Verify Current Conventions
   ├── Consult claude-docs (or fallback chain) for latest:
   │   ├── plugin.json schema
   │   ├── hooks.json format
   │   ├── SKILL.md frontmatter fields
   │   └── marketplace.json plugin entry format
   └── Cross-reference with existing plugins in repo-map.md

3. Generate Plugin Structure
   ├── Create directory tree based on plugin type
   ├── Populate plugin.json from template (plugin-templates.md)
   ├── If hooks → generate hooks.json + script skeleton
   │   └── Script outputs valid hook JSON format
   ├── If skills → generate SKILL.md with proper frontmatter
   ├── If MCP → add mcpServers config with env var interpolation
   └── chmod +x any generated scripts

4. Register in Marketplace
   ├── Add entry to .claude-plugin/marketplace.json
   ├── Maintain existing ordering pattern
   └── Validate: claude plugin validate .

5. Local Test Setup
   ├── Generate claude command:
   │   claude --plugin-dir /home/cp/code/dkmaker/my-claude-plugins/<name>
   ├── List what to verify based on components
   └── Remind: scripts must be executable

6. Update Repo Map
   └── Regenerate reference/repo-map.md with the new plugin

7. Commit
   ├── feat(<name>): add <name> plugin
   ├── All new files in one commit
   └── Ready for PR via develop workflow
```

## Reference: repo-map.md

A living inventory of the entire repository. Gets **regenerated** (not patched) by scanning the filesystem whenever structural changes happen.

Contains:
- **Plugins overview table**: name, version, type, category, components
- **Per-plugin detail**: file paths for plugin.json, hooks, skills, commands, scripts, MCP configs
- **File conventions**: hook JSON format, commit style, branch naming, directory rules

## Reference: plugin-templates.md

Boilerplate templates with inline comments:
- Feature plugin `plugin.json`
- MCP wrapper `plugin.json` (with `mcpServers`)
- `hooks.json` — SessionStart pattern
- Hook script skeleton (valid JSON output)
- `SKILL.md` — standard (auto + user invocable)
- `SKILL.md` — user-only (`disable-model-invocation: true`)
- Marketplace entry JSON

## Design Decisions

1. **Single skill with supporting files** over multiple skills: keeps one entry point, loads detailed workflow docs on demand, avoids context bloat.
2. **Auto-detection** over explicit mode switching: reduces friction, the skill figures out your context.
3. **Regenerate repo-map** over incremental patches: prevents drift, always accurate.
4. **claude-docs dependency** with fallback chain: source of truth for Claude Code conventions, graceful degradation if not available.
5. **Dedicated plugin** over personal/project skill: distributable via marketplace, installable by anyone working on the repo.
