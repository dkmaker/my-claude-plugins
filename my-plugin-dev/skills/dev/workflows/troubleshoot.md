# Workflow: Troubleshoot

Diagnostic guide for when plugins, hooks, skills, or MCP servers aren't working.

## 1. Identify the Problem

From user input or ask:

- **Hook not running / wrong output**
- **Skill not appearing / not triggering**
- **MCP server not connecting**
- **Plugin not loading at all**
- **Cache out of sync with source**

## 2. Environment Check (always run first)

```bash
# Where are we?
pwd
git status --short --branch

# Claude Code version
claude --version

# Dev mode or production mode?
# Check if running with --plugin-dir (dev) or from cache (production)
ls ~/.claude/plugins/cache/my-claude-plugins/ 2>/dev/null
```

### Cache vs Source Comparison

Compare what's installed vs what's in the repo:

```bash
# For a specific plugin, compare directory contents
diff <(cd ~/.claude/plugins/cache/my-claude-plugins/<plugin> && find . -type f | sort) \
     <(cd /home/cp/code/dkmaker/my-claude-plugins/<plugin> && find . -type f | sort)
```

If there are differences, the cache is stale. Solutions:
1. **For development**: Restart with `claude --plugin-dir /home/cp/code/dkmaker/my-claude-plugins/<plugin>`
2. **For reinstall**: `/plugin uninstall <plugin>@my-claude-plugins` then `/plugin install <plugin>@my-claude-plugins`

## 3. Diagnostics by Component Type

### Hooks

```bash
# Is hooks.json valid JSON?
jq . <plugin>/hooks/hooks.json

# Are scripts executable?
ls -la <plugin>/hooks/scripts/

# Test script in isolation (should output valid hook JSON)
bash <plugin>/hooks/scripts/<script>.sh | jq .
```

**Expected hook output format:**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Text injected into Claude's context"
  },
  "systemMessage": "Text shown to user"
}
```

**Common hook failures:**
| Symptom | Cause | Fix |
|---------|-------|-----|
| Script not found | Wrong path in hooks.json | Use `${CLAUDE_PLUGIN_ROOT}/hooks/scripts/name.sh` |
| No output | Script not executable | `chmod +x hooks/scripts/name.sh` |
| Invalid JSON | Missing quotes, trailing comma | Validate with `jq .` |
| Timeout | Script takes too long | Increase `timeout` in hooks.json or optimize script |
| Silent failure | `set -e` exits on error | Run manually to see stderr |

For current hook format reference: `claude-docs get hooks-guide` and `claude-docs get hooks`

### Skills

```bash
# Check SKILL.md exists in correct location
ls <plugin>/skills/*/SKILL.md

# Verify YAML frontmatter (extract between --- markers)
sed -n '/^---$/,/^---$/p' <plugin>/skills/<name>/SKILL.md
```

**Common skill failures:**
| Symptom | Cause | Fix |
|---------|-------|-----|
| Not in /help menu | Missing or empty `description` | Add description to frontmatter |
| Claude doesn't use it | `disable-model-invocation: true` | Remove if you want auto-invocation |
| Not visible at all | Wrong directory structure | Must be `skills/<name>/SKILL.md`, not inside `.claude-plugin/` |
| Truncated | Too many skills, budget exceeded | Check `/context` for warnings |
| Can't find supporting files | Files not in skill directory | Reference with relative paths from SKILL.md |

For current skill format reference: `claude-docs get skills`

### MCP Servers

```bash
# Check MCP config in plugin.json
jq '.mcpServers' <plugin>/.claude-plugin/plugin.json

# Check if command exists
which npx && npx -y <package> --help 2>&1 | head -5

# Check required env vars
echo "API_KEY set: ${API_KEY:+yes}"
```

**Common MCP failures:**
| Symptom | Cause | Fix |
|---------|-------|-----|
| Server not starting | Command not found | Install Node.js / npx |
| Auth error | Missing API key | Set env var in `.claude/settings.local.json` or shell config |
| Tools not appearing | Server crash on start | Check `claude --debug` output |
| Timeout | Slow server startup | Check network, package download |

For current MCP format reference: `claude-docs get mcp`

### Plugin Not Loading

```bash
# Does plugin.json exist and parse?
jq . <plugin>/.claude-plugin/plugin.json

# Is it registered in marketplace?
jq '.plugins[] | select(.name == "<plugin>")' .claude-plugin/marketplace.json

# Is it enabled in user settings?
jq '.enabledPlugins' ~/.claude/settings.json 2>/dev/null

# Check with debug mode
claude --debug 2>&1 | head -50
```

**Common loading failures:**
| Symptom | Cause | Fix |
|---------|-------|-----|
| Not in plugin list | Not registered in marketplace.json | Add entry |
| Registered but not loading | Invalid plugin.json | Validate with `jq .` |
| Components missing | Files inside `.claude-plugin/` | Move to plugin root |
| Name conflict | Duplicate plugin name | Use unique kebab-case name |

For current plugin format reference: `claude-docs get plugins-reference`

## 4. Resolution

1. Apply the fix
2. If it was a cache issue, provide the command:
   - Dev mode: `claude --plugin-dir /home/cp/code/dkmaker/my-claude-plugins/<plugin>`
   - Reinstall: `/plugin uninstall <plugin>@my-claude-plugins && /plugin install <plugin>@my-claude-plugins`
3. Verify the fix works
4. If structural changes were made, update [repo-map.md](../reference/repo-map.md)
