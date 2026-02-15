# Workflow: Develop

Full development lifecycle for making changes to an existing plugin.

## 1. Sync & Branch

```bash
# Fetch latest from origin
git fetch origin

# Check current branch
git branch --show-current
```

- **If on `main`**: Create a feature branch:
  ```bash
  git checkout -b feat/<plugin-name>-<brief-description>
  ```
- **If on a feature branch**: Verify it's up to date:
  ```bash
  git log --oneline origin/main..HEAD
  ```

## 2. Identify Target Plugin

Determine which plugin to work on:

1. From `$ARGUMENTS[1]` if the user provided a plugin name
2. From CWD if currently inside a plugin directory
3. Ask the user — show the plugin list from [repo-map.md](../reference/repo-map.md)

Once identified, load the plugin's detail section from repo-map.md to understand its current structure.

## 3. Make Changes

- Show the user the plugin's current file tree
- Reference [repo-map.md](../reference/repo-map.md) for full component inventory
- Before creating or modifying any component, consult `claude-docs` for the current format:
  - Hooks: `claude-docs get hooks-guide` and `claude-docs get hooks`
  - Skills: `claude-docs get skills`
  - Plugin manifest: `claude-docs get plugins-reference`
  - MCP config: `claude-docs get mcp`
- Reference [plugin-templates.md](../reference/plugin-templates.md) for boilerplate
- Follow existing repo patterns for consistency

## 3.1. Version Bumping (CRITICAL)

**ALWAYS bump the version** when making changes to a plugin. Follow semantic versioning:

| Change Type | Version Bump | Example |
|-------------|--------------|---------|
| **Bugfix** (fix commit) | Patch (`x.y.Z`) | 1.2.3 → 1.2.4 |
| **New feature** (feat commit) | Minor (`x.Y.0`) | 1.2.3 → 1.3.0 |
| **Breaking change** | Major (`X.0.0`) | 1.2.3 → 2.0.0 |
| **Docs only** | No bump | Keep current |
| **Chore/style** | No bump | Keep current |

**Version lives in ONE place only: `plugin.json`**

Update `<plugin>/.claude-plugin/plugin.json` → `"version": "x.y.z"`

**DO NOT add version to marketplace.json plugin entries.** Per official Claude Code docs, `plugin.json` takes priority and you only need to set it in one place. Duplicating it in marketplace.json causes version drift.

**Exception:** Plugins with no local `plugin.json` (e.g., external GitHub sources like `mcp-rest-api`) must have their version in marketplace.json since that's the only place to declare it.

**For forked plugins** (like superpowers):
- Update version in `plugin.json` only
- Document the change in `INTEGRATION.md` with version and change summary

## 4. Local Testing

Generate the exact command for the user to test their changes:

**Single plugin under development:**
```
claude --plugin-dir /home/cp/code/dkmaker/my-claude-plugins/<plugin-name>
```

**Multiple plugins (e.g., plugin + its dependency):**
```
claude --plugin-dir /home/cp/code/dkmaker/my-claude-plugins/<plugin-a> --plugin-dir /home/cp/code/dkmaker/my-claude-plugins/<plugin-b>
```

**What to test based on what changed:**

| Changed component | How to test |
|-------------------|-------------|
| SessionStart hook | Restart Claude Code, check startup output |
| Hook script | Run manually: `bash <script> \| jq .` |
| Skill (SKILL.md) | Invoke: `/my-plugin-dev:<skill-name>` or ask Claude a matching question |
| MCP server config | Check `/mcp` for server status and available tools |
| Command (.md) | Invoke: `/<command-name>` |
| plugin.json | Check `/plugin` list, verify metadata |

**IMPORTANT**: Remind the user they must restart Claude Code to pick up changes when using `--plugin-dir`.

## 5. Validate

Run these checks before committing:

```bash
# JSON syntax validation
jq . <plugin>/hooks/hooks.json 2>&1 || echo "FAIL: hooks.json"
jq . <plugin>/.claude-plugin/plugin.json 2>&1 || echo "FAIL: plugin.json"
jq . .claude-plugin/marketplace.json 2>&1 || echo "FAIL: marketplace.json"

# Check scripts are executable
find <plugin> -name "*.sh" ! -perm -111 -print

# Validate plugin structure
claude plugin validate /home/cp/code/dkmaker/my-claude-plugins/<plugin>
```

For SKILL.md files, verify the YAML frontmatter has:
- `name` field (or uses directory name)
- `description` field (required for auto-invocation)
- Valid `allowed-tools` if specified

**CRITICAL: Marketplace consistency check:**

`name` and `source` MUST be consistent between `plugin.json`, `marketplace.json`, and the directory name. Version must NOT be duplicated in marketplace.json (except for external plugins).

```bash
# For each modified plugin, verify consistency
for dir in <changed-plugin-dirs>; do
  dir_name=$(basename "$dir")
  plugin_name=$(jq -r '.name' "$dir/.claude-plugin/plugin.json")
  market_name=$(jq -r ".plugins[] | select(.source == \"./$dir_name\") | .name" .claude-plugin/marketplace.json)
  market_source=$(jq -r ".plugins[] | select(.name == \"$plugin_name\") | .source" .claude-plugin/marketplace.json)
  market_v=$(jq -r ".plugins[] | select(.name == \"$plugin_name\") | .version" .claude-plugin/marketplace.json)

  errors=0

  # 1. Name must match between plugin.json and directory
  if [ "$plugin_name" != "$dir_name" ]; then
    echo "ERROR: Name mismatch - directory='$dir_name', plugin.json name='$plugin_name'"
    errors=1
  fi

  # 2. Name must match in marketplace.json
  if [ "$plugin_name" != "$market_name" ]; then
    echo "ERROR: Name mismatch - plugin.json='$plugin_name', marketplace.json='$market_name'"
    errors=1
  fi

  # 3. Source path must match directory
  if [ "$market_source" != "./$dir_name" ]; then
    echo "ERROR: Source mismatch - marketplace.json source='$market_source', expected='./$dir_name'"
    errors=1
  fi

  # 4. Version must NOT be in marketplace.json for local plugins
  if [ "$market_v" != "null" ]; then
    echo "ERROR: Remove version from marketplace.json for '$plugin_name' — version belongs only in plugin.json"
    errors=1
  fi

  if [ $errors -eq 0 ]; then
    echo "OK: $dir_name (v$(jq -r '.version' "$dir/.claude-plugin/plugin.json")) - all consistent"
  fi
done
```

**Common mistakes this catches:**
- Renaming a directory but forgetting to update marketplace.json source path
- Renaming a plugin but forgetting to update marketplace.json name
- Adding version to marketplace.json for a local plugin (causes drift)

If any mismatch is found, fix ALL locations before committing.

## 6. Update Repo Map

If ANY structural changes were made, regenerate [repo-map.md](../reference/repo-map.md):

**Triggers for repo-map update:**
- New or removed plugin directories
- Added/removed/renamed skills or commands
- Changed hook configurations (new hooks, removed hooks, changed scripts)
- MCP server additions/removals
- Version bumps in plugin.json or marketplace.json
- New scripts or supporting files

**How to update**: Scan the filesystem and rebuild the entire repo-map.md. Do NOT patch it — regenerate to prevent drift. Include the repo-map changes in the same commit as the plugin changes.

## 7. Commit & PR

```bash
# Stage only the changed plugin's files (+ repo-map if updated)
git add <plugin>/
git add my-plugin-dev/skills/dev/reference/repo-map.md  # if updated

# Conventional commit
git commit -m "feat(<plugin>): <brief description of change>"
# or: fix(<plugin>):, docs(<plugin>):

# Push and create PR
git push -u origin <branch-name>
```

When creating the PR, include:
- Summary of what changed
- Which plugin was modified
- Testing instructions (the exact `claude --plugin-dir` command)
- What to verify (based on component type)
