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
- **deployment** → `third-party-integrations`, `amazon-bedrock`, `google-vertex-ai`, `azure-ai-foundry`, `network-config`, `llm-gateway`, `devcontainer`, `sandboxing`
- **security/iam** → `security`, `iam`
- **monitoring** → `monitoring-usage`, `analytics`, `costs`

**How to find all related slugs:**
1. Look at the preloaded documentation list above
2. Search for ALL slugs containing the topic keyword (case-insensitive)
3. Include plural/singular variations (plugin/plugins, hook/hooks)
4. Check for patterns: `<topic>`, `<topic>-guide`, `<topic>-reference`, `<topic>-<subtopic>`

**Critical: Load ALL matches, not just the first one!**

### STEP 3: Load the documentation

**For exact commands:**

- **list**: `!claude-expert/scripts/claude-docs.sh list`
- **list <slug>**: `!claude-expert/scripts/claude-docs.sh list <slug>`
- **get <slug>**: `!claude-expert/scripts/claude-docs.sh get '<slug>'`
- **get <slug>#<anchor>**: `!claude-expert/scripts/claude-docs.sh get '<slug>#<anchor>'`
- **search <query>**: `!claude-expert/scripts/claude-docs.sh search '<query>'`

**For topic-based requests (e.g., "fetch docs about plugins"):**

1. Identify the topic from the request
2. Search the preloaded list above for ALL slugs containing that topic
3. Load EACH relevant slug using `!claude-expert/scripts/claude-docs.sh get '<slug>'`
4. Inform the user of ALL sections loaded

**Example for "plugins" topic:**
```bash
!claude-expert/scripts/claude-docs.sh get plugins
!claude-expert/scripts/claude-docs.sh get plugin-marketplaces
!claude-expert/scripts/claude-docs.sh get plugins-reference
```

**Example for "hooks" topic:**
```bash
!claude-expert/scripts/claude-docs.sh get hooks-guide
!claude-expert/scripts/claude-docs.sh get hooks
```

### STEP 4: Inform the user what was loaded

After loading documentation, clearly state:
1. **What sections were loaded** - List all slugs retrieved
2. **What the user can now ask about** - Summarize the topics covered
3. **Offer to load more** - Suggest related documentation if relevant

### Important Notes:

1. **Load ALL related documentation** - Don't just load one section if multiple exist for a topic
2. **Always use quotes** around arguments with special characters: `get 'plugins#quickstart'`
3. **Read-only mode** - Only load docs, no code changes
4. **Be comprehensive** - When in doubt, load more rather than less
5. **Tool reference** - Always use full path: `claude-expert/scripts/claude-docs.sh`

### Example Responses:

**User runs:** `/claude-docs fetch docs about plugins`
**You should:**
1. Identify "plugins" as the topic
2. Find ALL related slugs: `plugins`, `plugin-marketplaces`, `plugins-reference`
3. Load all three sections
4. Say: "I've loaded all plugins-related documentation (3 sections: main guide, marketplaces, and reference). What would you like to know about creating or managing plugins?"

**User runs:** `/claude-docs get hooks`
**You should:**
1. Recognize this could mean ALL hooks documentation
2. Load both `hooks-guide` AND `hooks` reference
3. Say: "I've loaded the hooks getting started guide and reference documentation. What would you like to know about hooks?"

**User runs:** `/claude-docs search mcp`
**You should:**
1. Run the search command
2. Show matching results
3. Offer to load the complete `mcp` documentation if they want full details

## Remember

- This command is for **loading documentation only** - no code changes
- The documentation is already locally cached and transforms MDX to readable markdown
- After loading docs, you're ready to answer questions about Claude Code plugin development
- Always inform the user what documentation you've loaded into context
