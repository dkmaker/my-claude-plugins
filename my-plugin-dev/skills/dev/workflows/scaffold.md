# Workflow: Scaffold

Create a brand new plugin from scratch with the correct structure, register it in the marketplace, and set up local testing.

## 1. Gather Requirements

Ask the user (one question at a time):

1. **Plugin name**: Must be kebab-case (lowercase, hyphens only). Will be used as:
   - Directory name
   - `name` field in plugin.json
   - Namespace prefix for skills: `/my-claude-plugins:<name>:<skill>`

   **IMPORTANT Naming Conventions:**
   - ❌ **DO NOT** add suffixes like `-skill`, `-plugin`, `-tool`
   - ❌ Bad: `playwright-cli-skill`, `web-search-plugin`, `my-tool-helper`
   - ✅ Good: `playwright-cli`, `web-search`, `my-tool`
   - **Reason**: The plugin type is already clear from context. Adding `-skill` or `-plugin` is redundant and verbose.

2. **Plugin type**:
   - **Feature plugin** — hooks, skills, scripts, commands
   - **MCP server wrapper** — thin config wrapping an external MCP server
   - **Hybrid** — MCP server + custom skills/hooks

3. **Description**: Brief description for marketplace listing

4. **Category**: One of: `knowledge`, `productivity`, `testing`, `creative`, `development`

5. **Components needed** (for feature/hybrid plugins):
   - SessionStart hook? (Y/N)
   - Skills? (how many, names)
   - Commands? (how many, names)
   - MCP server config? (server name, npm package, env vars)
   - Scripts? (what they do)

## 2. Verify Current Conventions

Before generating anything, consult documentation for the latest formats:

```bash
# Check claude-docs is available
command -v claude-docs

# Load relevant docs
claude-docs get plugins-reference  # plugin.json schema
claude-docs get hooks-guide        # hooks.json format
claude-docs get skills             # SKILL.md frontmatter
claude-docs get plugin-marketplaces # marketplace entry format
```

If `claude-docs` is unavailable, follow the fallback chain from the main SKILL.md.

Also cross-reference with existing plugins in [repo-map.md](../reference/repo-map.md) to stay consistent with local patterns.

## 3. Generate Plugin Structure

Using templates from [plugin-templates.md](../reference/plugin-templates.md), create the plugin:

### For Feature Plugins:

```bash
# Create directory structure
mkdir -p <name>/.claude-plugin
mkdir -p <name>/hooks/scripts     # if hooks needed
mkdir -p <name>/skills/<skill>/   # for each skill
mkdir -p <name>/commands/         # if commands needed
mkdir -p <name>/scripts/          # if helper scripts needed
```

Generate files from templates, substituting:
- `PLUGIN_NAME` → the chosen name
- `BRIEF_DESCRIPTION` → the provided description
- `KEYWORD1`, `KEYWORD2` → relevant keywords
- Hook script content → based on plugin's purpose
- SKILL.md content → based on skill requirements

### For MCP Wrappers:

```bash
mkdir -p <name>/.claude-plugin
```

Generate `plugin.json` with `mcpServers` configuration.

### For All Plugins:

```bash
# Make all scripts executable
find <name> -name "*.sh" -exec chmod +x {} \;
```

## 4. Register in Marketplace

Add entry to `.claude-plugin/marketplace.json`:

```bash
# Show current entries for reference
jq '.plugins[].name' .claude-plugin/marketplace.json
```

Add the new entry to the `plugins` array. Use the marketplace entry template from plugin-templates.md.

**CRITICAL: The marketplace entry MUST be consistent with the plugin directory and plugin.json:**
- `"name"` in marketplace.json === `"name"` in plugin.json === directory name
- `"source"` in marketplace.json === `./<directory-name>`
- `"version"` in marketplace.json === `"version"` in plugin.json

Validate after adding:

```bash
# JSON syntax check
jq . .claude-plugin/marketplace.json > /dev/null && echo "Valid JSON"

# Consistency check (name + source + version all match)
dir_name="<name>"
plugin_name=$(jq -r '.name' "$dir_name/.claude-plugin/plugin.json")
plugin_v=$(jq -r '.version' "$dir_name/.claude-plugin/plugin.json")
market_name=$(jq -r ".plugins[] | select(.source == \"./$dir_name\") | .name" .claude-plugin/marketplace.json)
market_source=$(jq -r ".plugins[] | select(.name == \"$plugin_name\") | .source" .claude-plugin/marketplace.json)
market_v=$(jq -r ".plugins[] | select(.name == \"$plugin_name\") | .version" .claude-plugin/marketplace.json)

[ "$plugin_name" = "$dir_name" ] && [ "$plugin_name" = "$market_name" ] && \
[ "$market_source" = "./$dir_name" ] && [ "$plugin_v" = "$market_v" ] && \
echo "✅ All consistent: $dir_name v$plugin_v" || echo "❌ MISMATCH - check name/source/version across all files"
```

## 5. Local Test Setup

Provide the user with the exact command to test:

```
claude --plugin-dir /home/cp/code/dkmaker/my-claude-plugins/<name>
```

**Verification checklist based on components:**

| Component | Verify |
|-----------|--------|
| plugin.json | Plugin appears in `/plugin` list |
| SessionStart hook | Check startup output after restart |
| Hook script | Run: `bash <script> \| jq .` |
| Skill | Invoke: `/my-claude-plugins:<name>:<skill>` |
| Command | Invoke: `/my-claude-plugins:<name>:<command>` |
| MCP server | Check `/mcp` for server status |

Remind: **Scripts must be executable** and **Claude Code must be restarted** to pick up new plugins.

## 6. Update Repo Map

Regenerate [repo-map.md](../reference/repo-map.md) with the new plugin included. Scan the filesystem — don't patch.

## 7. Commit

```bash
git add <name>/
git add .claude-plugin/marketplace.json
git add my-plugin-dev/skills/dev/reference/repo-map.md

git commit -m "feat(<name>): add <name> plugin"
```

The plugin is now ready. If further development is needed, switch to the [develop workflow](develop.md).
