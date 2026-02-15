# my-claude-plugins Repository Map

> This file is auto-regenerated. Do not edit manually — it gets rebuilt when structural changes are made via the dev skill.
> **Versions are NOT tracked here.** Check `plugin.json` for local plugins or `marketplace.json` for external plugins.

## Repository

- **Location**: /home/cp/code/dkmaker/my-claude-plugins
- **GitHub**: dkmaker/my-claude-plugins
- **Branch convention**: `feat/<plugin-name>-<description>`
- **Commit convention**: `feat(<plugin>):` / `fix(<plugin>):` / `docs(<plugin>):`

## Plugins Overview

| Plugin | Type | Category | Components |
|--------|------|----------|------------|
| baseline | Feature | productivity | hooks, statusline |
| claude-expert | Feature | knowledge | hooks, skills |
| generate-image | Feature | creative | skills |
| image-tools | Feature | creative | skills |
| mcp-rest-api | External (GitHub) | productivity | mcpServers |
| my-plugin-dev | Feature | development | skills |
| perplexity | MCP wrapper | productivity | mcpServers |
| playwright | MCP wrapper | testing | mcpServers |
| playwright-cli | Feature | testing | skills |
| superpowers | Feature | productivity | hooks, skills, agents |
| transcript | Feature | productivity | hooks, commands, scripts |
| web-search | Feature | productivity | skills |
| wsl-ssh-agent | Feature | productivity | hooks, scripts |

## Per-Plugin Detail

### baseline — Feature plugin
- **Manifest**: `baseline/.claude-plugin/plugin.json`
- **Hooks**: `baseline/hooks/hooks.json`
  - SessionStart → `baseline/hooks/scripts/baseline-check.sh` (10s timeout)
- **Statusline**: `baseline/statusline.sh`
- **Dependencies**: jq (critical), git (critical), ripgrep (optional)
- **Behavior**: Validates tools, applies recommended settings with 2-hour throttling, creates settings backups

### claude-expert — Feature plugin
- **Manifest**: `claude-expert/.claude-plugin/plugin.json`
- **Hooks**: `claude-expert/hooks/hooks.json`
  - SessionStart → `claude-expert/hooks/scripts/sessionstart.sh` (5s timeout)
- **Skills**: `claude-expert/skills/docs/SKILL.md`
  - `/my-claude-plugins:claude-expert:docs` — loads Claude Code documentation via `claude-docs` CLI
  - allowed-tools: `Bash(claude-docs:*)`
- **External CLI**: `claude-docs` (installed globally by the SessionStart hook from GitHub releases)
- **Behavior**: Installs/updates claude-docs CLI, injects system prompt to use docs skill

### generate-image — Feature plugin
- **Manifest**: `generate-image/.claude-plugin/plugin.json`
- **Skills**: `generate-image/skills/gemini/SKILL.md`
  - `/my-claude-plugins:generate-image:gemini` — AI image generation via Google Gemini
  - allowed-tools: `Bash, Write, Read, Glob, AskUserQuestion`
  - argument-hint: `[prompt description or 'interactive' for guided mode]`
- **Scripts**: `generate-image/skills/gemini/scripts/` (check-setup.sh, generate.sh, image_gen.py)
- **Dependencies**: Python 3.x, venv, GEMINI_API_KEY

### image-tools — Feature plugin
- **Manifest**: `image-tools/.claude-plugin/plugin.json`
- **Skills**: `image-tools/skills/image/SKILL.md`
  - `/my-claude-plugins:image-tools:image` — Swiss army knife for image manipulation
  - allowed-tools: `Bash, Read, Write, Glob, AskUserQuestion`
  - argument-hint: `[operation] [image path] [options]`
- **Scripts**: `image-tools/skills/image/scripts/` (check-setup.sh, run.sh, image_tools.py, ops/)
  - ops modules: `__init__.py`, `resize.py`, `crop.py`, `convert.py`, `alpha.py`, `transform.py`, `analyze.py`
- **Instruction files**: `image-tools/skills/image/instructions/` (6 files)
  - resize-and-scale.md, crop-and-trim.md, convert-and-compress.md, alpha-and-composite.md, transform.md, analyze.md
- **Subcommands** (13): resize, thumbnail, crop, trim, pad, convert, compress, alpha, composite, rotate, flip, info, metadata
- **Dependencies**: Python 3.8+, Pillow (venv)

### mcp-rest-api — External plugin (GitHub)
- **Source**: `dkmaker/mcp-rest-api` (GitHub repo, not local)
- **Type**: MCP server for REST API testing
- **Note**: Version tracked in marketplace.json (no local plugin.json)

### my-plugin-dev — Feature plugin
- **Manifest**: `my-plugin-dev/.claude-plugin/plugin.json`
- **Skills**: `my-plugin-dev/skills/dev/SKILL.md`
  - `/my-claude-plugins:my-plugin-dev:dev` — development toolkit
  - allowed-tools: `Bash, Read, Write, Edit, Glob, Grep, Bash(git:*), Bash(claude:*)`
  - argument-hint: `[develop|troubleshoot|scaffold] [plugin-name]`
  - Workflows: develop, troubleshoot, scaffold
  - Supporting files in `workflows/` and `reference/`

### perplexity — MCP wrapper
- **Manifest**: `perplexity/.claude-plugin/plugin.json`
- **MCP Server**: `npx -y @perplexity-ai/mcp-server`
  - Env: `PERPLEXITY_API_KEY` (required), `PERPLEXITY_TIMEOUT_MS` (optional)
- **Tools provided**: perplexity_ask, perplexity_search, perplexity_reason, perplexity_research

### playwright — MCP wrapper
- **Manifest**: `playwright/.claude-plugin/plugin.json`
- **MCP Server**: `npx -y @playwright/mcp@latest`
- **Tools provided**: Browser automation (navigate, click, screenshot, etc.)

### playwright-cli — Feature plugin
- **Manifest**: `playwright-cli/.claude-plugin/plugin.json`
- **Skills**: `playwright-cli/skills/playwright-cli/SKILL.md`
  - `/my-claude-plugins:playwright-cli:playwright-cli` — browser automation via playwright-cli
  - allowed-tools: `Bash(playwright-cli:*)`
- **References**: `playwright-cli/skills/playwright-cli/references/` (7 files)
  - request-mocking.md, running-code.md, session-management.md, storage-state.md, test-generation.md, tracing.md, video-recording.md
- **Dependencies**: playwright-cli (npm global)

### superpowers — Feature plugin
- **Manifest**: `superpowers/.claude-plugin/plugin.json`
- **Hooks**: `superpowers/hooks/hooks.json`
  - SessionStart → `superpowers/hooks/session-start.sh` (matcher: startup|resume|clear|compact)
- **Skills** (15):
  - `brainstorming/SKILL.md`
  - `dispatching-parallel-agents/SKILL.md`
  - `executing-plans/SKILL.md`
  - `finishing-a-development-branch/SKILL.md`
  - `headless-runner/SKILL.md` + `headless-runner/claude-runner.js`
  - `receiving-code-review/SKILL.md`
  - `requesting-code-review/SKILL.md`
  - `subagent-driven-development/SKILL.md`
  - `systematic-debugging/SKILL.md`
  - `test-driven-development/SKILL.md`
  - `using-git-worktrees/SKILL.md`
  - `using-superpowers/SKILL.md`
  - `verification-before-completion/SKILL.md`
  - `writing-plans/SKILL.md`
  - `writing-skills/SKILL.md`
- **Agents**: `superpowers/agents/code-reviewer.md`
- **Origin**: Forked from obra/superpowers for local customization

### transcript — Feature plugin
- **Manifest**: `transcript/.claude-plugin/plugin.json`
- **Hooks**: `transcript/hooks/hooks.json`
  - SessionStart → `transcript/hooks/scripts/sessionstart.sh`
- **Commands**:
  - `transcript/commands/create.md` — `/transcript:create` generates HTML report
  - `transcript/commands/help.md` — `/transcript:help` shows usage guide
- **Scripts**: `transcript/scripts/` (create-transcript.sh, normalize-transcript.sh, render-html-js.sh)
- **Behavior**: Sets CLAUDE_ACTIVE_TRANSCRIPT, CLAUDE_SESSION_ID env vars

### web-search — Feature plugin
- **Manifest**: `web-search/.claude-plugin/plugin.json`
- **Skills**: `web-search/skills/search/SKILL.md`
  - `/my-claude-plugins:web-search:search` — web search via Perplexity AI subagent
  - argument-hint: `[ask|search|reason|research] <query>`
  - disable-model-invocation: true (delegates to subagent)
- **Scripts**: `web-search/skills/search/scripts/` (update-index.sh, list.sh, slug.sh)
- **Dependencies**: PERPLEXITY_API_KEY, web-search custom agent

### wsl-ssh-agent — Feature plugin
- **Manifest**: `wsl-ssh-agent/.claude-plugin/plugin.json`
- **Hooks**: `wsl-ssh-agent/hooks/hooks.json`
  - SessionStart → `wsl-ssh-agent/hooks/scripts/ssh-agent-bridge.sh` (15s timeout)
- **Binary**: `wsl-ssh-agent/bin/npiperelay.exe`
- **Dependencies**: WSL2, socat, Windows SSH agent (1Password or native)
- **Behavior**: Bridges Windows SSH agent to WSL via npiperelay.exe + socat + Unix socket

## File Conventions

- **Hook JSON output format**: `{ "hookSpecificOutput": { "hookEventName": "SessionStart", "additionalContext": "..." }, "systemMessage": "..." }`
- **Plugin components**: Always at plugin root level, NEVER inside `.claude-plugin/`
- **MCP env vars**: Use `${ENV_VAR}` syntax for interpolation at runtime
- **Scripts**: Must be executable (`chmod +x`)
- **Plugin cache**: `~/.claude/plugins/cache/my-claude-plugins/<plugin-name>/`
- **Local dev**: Use `claude --plugin-dir /home/cp/code/dkmaker/my-claude-plugins/<plugin-name>`
- **Versions**: Check `<plugin>/.claude-plugin/plugin.json` — never duplicated in this file or marketplace.json
