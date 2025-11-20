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

### STEP 1: Understand what documentation to load

First, analyze the request to understand what topic the user wants:

**Exact command syntax (starts with known commands):**
- If starts with "list": Direct list command
- If starts with "get": Direct get command
- If starts with "search": Direct search command

**Topic-based request (natural language):**
- Extract the topic keyword (e.g., "plugins", "hooks", "mcp", "skills", "agents")
- Need to find ALL related documentation sections for comprehensive coverage

### STEP 2: Find ALL related documentation

**For topic-based requests**, you must load ALL related slugs. Use this reference:

**Common Topic Mappings (load ALL listed):**
- **plugins** → `plugins`, `plugin-marketplaces`, `plugins-reference`
- **hooks** → `hooks-guide`, `hooks`
- **skills** → `skills`
- **mcp** → `mcp`
- **agents/subagents** → `sub-agents`
- **slash commands** → `slash-commands`
- **settings** → `settings`
- **security/iam** → `security`, `iam`
- **monitoring** → `monitoring-usage`, `analytics`, `costs`

**How to find all related slugs:**
1. Look at the preloaded documentation list above
2. Search for ALL slugs containing the topic keyword (case-insensitive)
3. Include plural/singular variations (plugin/plugins, hook/hooks)
4. Check for patterns: `<topic>`, `<topic>-guide`, `<topic>-reference`, `<topic>-<subtopic>`

**Critical: Load ALL matches, not just the first one!**

### STEP 3: Load the documentation

**Understanding the tools:**

- **`list`** - Shows all available documentation sections (already preloaded above)
- **`list <slug>`** - Shows the TABLE OF CONTENTS for a specific document (useful for browsing structure)
- **`get <slug>`** - Loads the ENTIRE document including ALL sections
- **`get <slug>#<anchor>`** - Loads ONLY a specific section (rarely needed - use sparingly!)
- **`search <query>`** - Searches across all documentation

**Default approach - Start simple:**

1. **For topic-based requests**, load full documents with `get <slug>`:
   ```bash
   !claude-expert/scripts/claude-docs.sh get plugins
   !claude-expert/scripts/claude-docs.sh get plugin-marketplaces
   !claude-expert/scripts/claude-docs.sh get plugins-reference
   ```

2. **Evaluate if you have enough** - The full documents include ALL their sections

3. **Only use anchors if:**
   - User specifically asked for one section (e.g., "get the quickstart section")
   - You want to show a TOC first with `list <slug>` then get a specific part
   - The document is huge and you only need one section

**For exact command syntax:**

- **`list`** → Already shown above, just reference it
- **`list <slug>`** → Show TOC: `!claude-expert/scripts/claude-docs.sh list <slug>`
- **`get <slug>`** → Load full doc: `!claude-expert/scripts/claude-docs.sh get '<slug>'`
- **`get <slug>#<anchor>`** → Only if specifically requested: `!claude-expert/scripts/claude-docs.sh get '<slug>#<anchor>'`
- **`search <query>`** → Search all docs: `!claude-expert/scripts/claude-docs.sh search '<query>'`

**Example workflow for "plugins" topic:**
```bash
# Load all full documents (includes all sections)
!claude-expert/scripts/claude-docs.sh get plugins
!claude-expert/scripts/claude-docs.sh get plugin-marketplaces
!claude-expert/scripts/claude-docs.sh get plugins-reference

# That's it! All sections are now loaded. No need for anchors.
```

### STEP 4: Inform the user what was loaded

After loading documentation, clearly state:
1. **What sections were loaded** - List all slugs retrieved
2. **What the user can now ask about** - Summarize the topics covered
3. **Offer to load more** - Suggest related documentation if relevant

### Important Principles:

1. **Start with full documents** - Use `get <slug>` to load entire documents (includes all sections)
2. **Load ALL related docs** - Don't just load one if multiple exist for a topic
3. **Avoid unnecessary anchors** - Only use `get <slug>#<anchor>` when specifically requested
4. **Read-only mode** - Only load docs, no code changes
5. **Be comprehensive** - When in doubt, load more full documents rather than less
6. **Tool reference** - Always use full path: `claude-expert/scripts/claude-docs.sh`

### Example Responses:

**User runs:** `/claude-docs fetch docs about plugins`
**You should:**
1. Identify "plugins" as the topic
2. Find ALL related slugs: `plugins`, `plugin-marketplaces`, `plugins-reference`
3. Load all three FULL documents (no anchors needed):
   ```bash
   !claude-expert/scripts/claude-docs.sh get plugins
   !claude-expert/scripts/claude-docs.sh get plugin-marketplaces
   !claude-expert/scripts/claude-docs.sh get plugins-reference
   ```
4. Say: "I've loaded all plugins documentation (3 complete sections). What would you like to know?"

**User runs:** `/claude-docs get plugins#quickstart`
**You should:**
1. User specifically requested the quickstart section only
2. Load just that section:
   ```bash
   !claude-expert/scripts/claude-docs.sh get 'plugins#quickstart'
   ```
3. Say: "I've loaded the plugins quickstart section. Would you like the full plugins documentation?"

**User runs:** `/claude-docs list hooks`
**You should:**
1. Show the table of contents for hooks:
   ```bash
   !claude-expert/scripts/claude-docs.sh list hooks
   ```
2. Ask: "Here's the hooks documentation structure. Would you like me to load the full documentation?"

## Key Principles (Read Carefully!)

**Default Loading Strategy:**
1. **Always start with full documents** - Use `get <slug>` to load entire documents
2. **Full document = ALL sections included** - When you `get plugins`, you get quickstart, installation, examples, everything!
3. **Anchors are for specific requests only** - Only use `get <slug>#<anchor>` if user explicitly asks for one section
4. **`list <slug>` is for browsing** - Shows table of contents, doesn't load content
5. **Load multiple related docs** - Get all relevant slugs for comprehensive coverage

**What NOT to do:**
- ❌ Don't use anchors unless specifically requested
- ❌ Don't load one section when the full document is better
- ❌ Don't assume you need to browse with `list` first - just load the full docs
- ❌ Don't modify files or write code - this is read-only documentation loading

**What to do:**
- ✅ Load full documents with `get <slug>`
- ✅ Load ALL related slugs for a topic
- ✅ Evaluate if you have enough information
- ✅ Inform user what was loaded and offer to answer questions

## Remember

- This command is for **loading documentation only** - no code changes
- `get <slug>` loads the ENTIRE document including all subsections
- Anchors are rarely needed - full documents are usually better
- After loading docs, you're ready to answer questions about Claude Code plugin development
- Always inform the user what documentation you've loaded into context
