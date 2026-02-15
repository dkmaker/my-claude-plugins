# my-claude-plugins Repository Map

> This file is auto-regenerated. Do not edit manually — it gets rebuilt when structural changes are made via the dev skill.

## Repository

- **Location**: /home/cp/code/dkmaker/my-claude-plugins
- **GitHub**: dkmaker/my-claude-plugins
- **Branch convention**: `feat/<plugin-name>-<description>`
- **Commit convention**: `feat(<plugin>):` / `fix(<plugin>):` / `docs(<plugin>):`

## Plugins Overview

| Plugin | Version | Type | Category | Components |
|--------|---------|------|----------|------------|
| baseline | 2.1.0 | Feature | productivity | hooks, statusline |
| claude-expert | 2.0.0 | Feature | knowledge | hooks, skills |
| generate-image | 1.1.0 | Feature | creative | skills |
| mcp-rest-api | — | External (GitHub) | productivity | mcpServers |
| my-plugin-dev | 1.0.0 | Feature | development | skills |
| perplexity | 0.5.0 | MCP wrapper | productivity | mcpServers |
| playwright | 1.0.0 | MCP wrapper | testing | mcpServers |
| transcript | 1.0.0 | Feature | productivity | hooks, commands, scripts |
| wsl-ssh-agent | 1.0.1 | Feature | productivity | hooks, scripts |

## Per-Plugin Detail

### baseline (v2.1.0) — Feature plugin
- **Manifest**: `baseline/.claude-plugin/plugin.json`
- **Hooks**: `baseline/hooks/hooks.json`
  - SessionStart → `baseline/hooks/scripts/baseline-check.sh` (10s timeout)
- **Statusline**: `baseline/statusline/statusline.sh`
- **Dependencies**: jq (critical), git (critical), ripgrep (optional)
- **Behavior**: Validates tools, applies recommended settings with 2-hour throttling, creates settings backups

### claude-expert (v2.0.0) — Feature plugin
- **Manifest**: `claude-expert/.claude-plugin/plugin.json`
- **Hooks**: `claude-expert/hooks/hooks.json`
  - SessionStart → `claude-expert/hooks/scripts/sessionstart.sh` (5s timeout)
- **Skills**: `claude-expert/skills/docs/SKILL.md`
  - `/my-claude-plugins:claude-expert:docs` — loads Claude Code documentation via `claude-docs` CLI
  - allowed-tools: `Bash(claude-docs:*)`
- **External CLI**: `claude-docs` (installed globally by the SessionStart hook from GitHub releases)
- **Behavior**: Installs/updates claude-docs CLI, injects system prompt to use docs skill

### generate-image (v1.1.0) — Feature plugin
- **Manifest**: `generate-image/.claude-plugin/plugin.json`
- **Skills**: `generate-image/skills/gemini/SKILL.md`
  - `/my-claude-plugins:generate-image:gemini` — AI image generation via Google Gemini
  - allowed-tools: `Bash, Write, Read, Glob, AskUserQuestion`
  - argument-hint: `[prompt description or 'interactive' for guided mode]`
- **Scripts**: `generate-image/skills/gemini/scripts/` (check-setup.sh, generate.sh)
- **Dependencies**: Python 3.x, venv, GEMINI_API_KEY

### mcp-rest-api — External plugin (GitHub)
- **Source**: `dkmaker/mcp-rest-api` (GitHub repo, not local)
- **Type**: MCP server for REST API testing

### my-plugin-dev (v1.0.0) — Feature plugin
- **Manifest**: `my-plugin-dev/.claude-plugin/plugin.json`
- **Skills**: `my-plugin-dev/skills/dev/SKILL.md`
  - `/my-claude-plugins:my-plugin-dev:dev` — development toolkit
  - Workflows: develop, troubleshoot, scaffold
  - Supporting files in `workflows/` and `reference/`

### perplexity (v0.5.0) — MCP wrapper
- **Manifest**: `perplexity/.claude-plugin/plugin.json`
- **MCP Server**: `npx -y @perplexity-ai/mcp-server`
  - Env: `PERPLEXITY_API_KEY` (required), `PERPLEXITY_TIMEOUT_MS` (optional)
- **Tools provided**: perplexity_ask, perplexity_search, perplexity_reason, perplexity_research

### playwright (v1.0.0) — MCP wrapper
- **Manifest**: `playwright/.claude-plugin/plugin.json`
- **MCP Server**: `npx -y @playwright/mcp@latest`
- **Tools provided**: Browser automation (navigate, click, screenshot, etc.)

### transcript (v1.0.0) — Feature plugin
- **Manifest**: `transcript/.claude-plugin/plugin.json`
- **Hooks**: `transcript/hooks/hooks.json`
  - SessionStart → `transcript/hooks/scripts/sessionstart.sh`
- **Commands**:
  - `transcript/commands/create.md` — `/transcript:create` generates HTML report
  - `transcript/commands/help.md` — `/transcript:help` shows usage guide
- **Scripts**: `transcript/scripts/` (transcript-helper.sh, normalize-transcript.sh, render-html-js.sh, create-transcript.sh)
- **Behavior**: Sets CLAUDE_ACTIVE_TRANSCRIPT, CLAUDE_SESSION_ID env vars

### wsl-ssh-agent (v1.0.1) — Feature plugin
- **Manifest**: `wsl-ssh-agent/.claude-plugin/plugin.json`
- **Hooks**: `wsl-ssh-agent/hooks/hooks.json`
  - SessionStart → `wsl-ssh-agent/hooks/scripts/ssh-agent-bridge.sh` (15s timeout)
- **Dependencies**: WSL2, socat, Windows SSH agent (1Password or native)
- **Behavior**: Bridges Windows SSH agent to WSL via npiperelay.exe + socat + Unix socket

## File Conventions

- **Hook JSON output format**: `{ "hookSpecificOutput": { "hookEventName": "SessionStart", "additionalContext": "..." }, "systemMessage": "..." }`
- **Plugin components**: Always at plugin root level, NEVER inside `.claude-plugin/`
- **MCP env vars**: Use `${ENV_VAR}` syntax for interpolation at runtime
- **Scripts**: Must be executable (`chmod +x`)
- **Plugin cache**: `~/.claude/plugins/cache/my-claude-plugins/<plugin-name>/`
- **Local dev**: Use `claude --plugin-dir /home/cp/code/dkmaker/my-claude-plugins/<plugin-name>`
