---
allowed-tools: Bash(claude-expert/scripts/claude-docs.sh:*)
argument-hint: [list|get <slug>[#anchor]|search <query>]
description: Load Claude Code documentation into context using the local docs CLI tool
---

# Claude Documentation Loader

This command loads official Claude Code documentation into the conversation context using the local `claude-docs.sh` CLI tool.

## Available Documentation Sections

!`claude-expert/scripts/claude-docs.sh list`

## Your Task

The user requested documentation with arguments: **$ARGUMENTS**

### Parse the request and load the appropriate documentation:

**If arguments start with "list":**
- If just "list": Show the available sections above (already loaded)
- If "list <slug>": Run `!claude-expert/scripts/claude-docs.sh list <slug>` to show the structure of that specific document

**If arguments start with "get":**
- Parse the slug (and optional #anchor)
- Run `!claude-expert/scripts/claude-docs.sh get '<slug>'` or `!claude-expert/scripts/claude-docs.sh get '<slug>#<anchor>'`
- Load the full documentation content into context

**If arguments start with "search":**
- Extract the search query (everything after "search")
- Run `!claude-expert/scripts/claude-docs.sh search '<query>'`
- Show matching sections with context

**If arguments are empty or unclear:**
- Show the user the available documentation sections (already preloaded above)
- Explain they can use:
  - `/claude-docs list` - See all available docs
  - `/claude-docs list <slug>` - See structure of a specific doc
  - `/claude-docs get <slug>` - Load full documentation
  - `/claude-docs get <slug>#<anchor>` - Load specific section
  - `/claude-docs search <query>` - Search across all docs

### Important Notes:

1. **Always use quotes** around arguments passed to the CLI tool, especially for anchors: `get 'plugins#quickstart'`
2. **Read-only mode**: You are only loading documentation into context. Do NOT attempt to modify files or write code.
3. **Context awareness**: After loading documentation, inform the user what was loaded and that you're ready to answer questions about it.
4. **Tool reference**: The CLI tool is at `claude-expert/scripts/claude-docs.sh` - always use the full path.

### Example Responses:

**User runs:** `/claude-docs get plugins`
**You should:** Run the bash command to load the plugins documentation, then say "I've loaded the complete plugins documentation into context. What would you like to know about creating or using plugins?"

**User runs:** `/claude-docs search mcp`
**You should:** Run the search command, show the results, then offer to load any specific sections they're interested in.

**User runs:** `/claude-docs list hooks`
**You should:** Show the structure of the hooks documentation so they can see what sections are available.

## Remember

- This command is for **loading documentation only** - no code changes
- The documentation is already locally cached and transforms MDX to readable markdown
- After loading docs, you're ready to answer questions about Claude Code plugin development
- Always inform the user what documentation you've loaded into context
