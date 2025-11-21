# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Claude Code plugin marketplace containing multiple plugins for enhancing development workflows. The repository uses a standardized plugin structure with marketplace metadata enabling distribution through the Claude Code plugin system.

## Architecture

### Plugin Marketplace Structure

- **Root `.claude-plugin/marketplace.json`**: Defines marketplace metadata and registers all available plugins
- **Individual plugins**: Each subdirectory (`baseline/`, `claude-expert/`, `perplexity/`, `playwright/`) contains a self-contained plugin
- **Plugin metadata**: Each plugin has `.claude-plugin/plugin.json` with name, version, description, and optional MCP server configuration

### Plugin Types

**1. Feature-based plugins** (baseline, claude-expert):
- Contain hooks, skills, scripts, and custom statusline
- No external dependencies beyond system tools
- Hooks execute on session start to configure environment

**2. MCP server plugins** (perplexity, playwright):
- Thin wrappers that configure external MCP servers
- Require Node.js (npx) to run MCP servers
- Configure via `mcpServers` object in plugin.json

### Key Components

**Hooks** (`hooks/hooks.json` + `hooks/scripts/`):
- SessionStart hooks run on every Claude Code session initialization
- Must output valid JSON with `hookSpecificOutput` and `systemMessage` keys
- Can inject additional context into Claude's system prompt
- Example: baseline-check.sh validates tools and applies settings

**Skills** (`skills/<name>/SKILL.md`):
- Markdown files with YAML frontmatter defining skill behavior
- Can specify allowed tools (restrict Claude to specific commands)
- Example: claude-expert docs skill loads documentation via CLI

**Scripts** (optional):
- Standalone CLI tools called by hooks or skills
- Note: claude-expert plugin uses globally installed `claude-docs` CLI (Node.js)

**Statusline** (`statusline.sh`):
- Custom status line script showing model info, version, and context
- Configured via baseline plugin's SessionStart hook

## Development Workflow

### Testing Plugin Changes

After modifying a plugin, test by reinstalling:
```bash
cd /home/cp/code/dkmaker/my-claude-plugins
/plugin uninstall my-claude-plugins/<plugin-name>
/plugin install my-claude-plugins/<plugin-name>
# Restart Claude Code to activate changes
```

### Adding a New Plugin

1. Create plugin directory: `mkdir new-plugin/`
2. Add metadata: `new-plugin/.claude-plugin/plugin.json`
3. Register in marketplace: Edit `.claude-plugin/marketplace.json` plugins array
4. Create plugin components (hooks, skills, scripts as needed)
5. Add README: `new-plugin/README.md`

### MCP Server Plugin Pattern

For wrapping an MCP server:
```json
{
  "name": "plugin-name",
  "mcpServers": {
    "server-name": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "package-name"],
      "env": {
        "API_KEY": "${ENV_VAR_NAME}"
      }
    }
  }
}
```

Environment variables are interpolated from user's environment at runtime.

## Important Implementation Details

### Hook JSON Output Format

Hooks must output valid JSON to stdout. Required structure:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Message added to Claude's context"
  },
  "systemMessage": "Message shown to user"
}
```

### Documentation CLI (`claude-docs`)

The claude-docs tool (Node.js) manages a local documentation database:
- Automatically installed/updated from GitHub releases by sessionstart.sh hook
- Downloads MDX from official Claude Code docs
- Transforms JSX/MDX to clean markdown (strips React components)
- Caches processed markdown for fast access
- Supports: `list`, `get <slug>`, `search <query>`, `update`, `cache` commands
- Stores docs in `~/.claude/docs/`
- Installed globally via npm from GitHub releases

### Baseline Settings Management (`baseline/hooks/scripts/baseline-check.sh`)

The baseline plugin:
- Validates critical tools (jq, git) and optional tools (ripgrep)
- Applies recommended settings to `~/.claude/settings.json`
- Manages settings compaction (autoCompactEnabled)
- Throttles checks (runs max every 2 hours via `~/.claude/.baseline-last-check`)
- Creates backups before modifying settings (keeps 10 backups)
- Reports detailed change summaries when settings are modified

### Session Hook Context Injection Pattern

The claude-expert plugin demonstrates how to inject instructions:
1. Hook script (`hooks/scripts/sessionstart.sh`) outputs JSON
2. `additionalContext` field contains markdown instructions
3. Instructions tell Claude to use the docs skill for Claude Code questions
4. This overrides Claude's default behavior to use outdated training data

## Git Workflow

This repository uses conventional commits:
- `feat(plugin-name):` for new features
- `fix(plugin-name):` for bug fixes
- `docs(plugin-name):` for documentation changes

Main branch: `main`

## Key Files to Understand

- `.claude-plugin/marketplace.json` - Marketplace registry
- `baseline/hooks/scripts/baseline-check.sh` - Settings validation and enforcement
- `claude-expert/hooks/scripts/sessionstart.sh` - CLI installation and update management
- `claude-expert/skills/docs/SKILL.md` - Skill definition with documentation loading logic
- `.claude/commands/claude-docs.md` - Slash command for manual documentation access

## Plugin Dependencies

**System requirements:**
- bash 4.0+ (for associative arrays in scripts)
- jq (critical - used by baseline and claude-docs)
- git (critical - for version control)
- curl (for claude-docs updates)
- node/npx (for MCP server plugins only)

**Optional:**
- ripgrep/rg (recommended by baseline)
- diff (for claude-docs update tracking)
