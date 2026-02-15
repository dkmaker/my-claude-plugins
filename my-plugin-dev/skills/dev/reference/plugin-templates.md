# Plugin Templates

> Templates for creating new plugins in the my-claude-plugins marketplace.
> Each template is derived from existing plugins in the repo.
> Before using these templates, verify current conventions via `claude-docs`.

## Feature Plugin — plugin.json

Based on: `baseline/.claude-plugin/plugin.json`

```json
{
  "name": "PLUGIN_NAME",
  "version": "1.0.0",
  "description": "BRIEF_DESCRIPTION",
  "author": {
    "name": "Christian Pedersen",
    "email": "christian@dkmaker.xyz"
  },
  "keywords": ["KEYWORD1", "KEYWORD2"]
}
```

## MCP Wrapper — plugin.json

Based on: `perplexity/.claude-plugin/plugin.json`

```json
{
  "name": "PLUGIN_NAME",
  "version": "1.0.0",
  "description": "BRIEF_DESCRIPTION",
  "author": {
    "name": "Christian Pedersen",
    "email": "christian@dkmaker.xyz"
  },
  "keywords": ["mcp", "KEYWORD1"],
  "mcpServers": {
    "SERVER_NAME": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "NPM_PACKAGE_NAME"],
      "env": {
        "API_KEY": "${ENV_VAR_NAME}"
      }
    }
  }
}
```

## hooks.json — SessionStart

Based on: `baseline/hooks/hooks.json`

```json
{
  "description": "WHAT_THIS_HOOK_DOES",
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/SCRIPT_NAME.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

## Hook Script Skeleton

Based on: `baseline/hooks/scripts/baseline-check.sh`

```bash
#!/usr/bin/env bash
# PLUGIN_NAME SessionStart hook
# PURPOSE_DESCRIPTION

set -euo pipefail

# ── Output valid hook JSON ──────────────────────────────────────
# Claude Code expects this exact format from hook scripts

additional_context="Instructions or context injected into Claude's prompt"
system_message="Message shown to user in the session start output"

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${additional_context}"
  },
  "systemMessage": "${system_message}"
}
EOF
```

## SKILL.md — Standard (auto + user invocable)

Based on: `claude-expert/skills/docs/SKILL.md`

```yaml
---
name: SKILL_NAME
description: WHAT_THIS_SKILL_DOES. Use when TRIGGER_CONDITIONS.
allowed-tools: TOOL1, TOOL2
---

# Skill Title

Instructions for Claude when this skill is invoked.

## When to Use

- Condition 1
- Condition 2

## How to Use

Step-by-step instructions.
```

## SKILL.md — User-Only (disable-model-invocation)

```yaml
---
name: SKILL_NAME
description: WHAT_THIS_SKILL_DOES
disable-model-invocation: true
argument-hint: "[ARG_DESCRIPTION]"
allowed-tools: TOOL1, TOOL2
---

# Skill Title

Instructions for Claude when user invokes /SKILL_NAME $ARGUMENTS.
```

## Marketplace Entry

Based on: `.claude-plugin/marketplace.json` entries

```json
{
  "name": "PLUGIN_NAME",
  "source": "./PLUGIN_NAME",
  "description": "BRIEF_DESCRIPTION",
  "version": "1.0.0",
  "keywords": ["KEYWORD1", "KEYWORD2"],
  "category": "CATEGORY"
}
```

Valid categories in this repo: `knowledge`, `productivity`, `testing`, `creative`, `development`

## Directory Structures

### Feature Plugin (hooks + skills)

```
PLUGIN_NAME/
├── .claude-plugin/
│   └── plugin.json
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       └── hook-script.sh    (chmod +x)
├── skills/
│   └── skill-name/
│       └── SKILL.md
└── README.md
```

### Feature Plugin (skills only)

```
PLUGIN_NAME/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── skill-name/
│       ├── SKILL.md
│       └── scripts/          (optional)
└── README.md
```

### MCP Wrapper

```
PLUGIN_NAME/
├── .claude-plugin/
│   └── plugin.json           (includes mcpServers)
└── README.md
```

### Feature Plugin (hooks + commands)

```
PLUGIN_NAME/
├── .claude-plugin/
│   └── plugin.json
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       └── hook-script.sh    (chmod +x)
├── commands/
│   └── command-name.md
├── scripts/                  (optional, for command helpers)
└── README.md
```
