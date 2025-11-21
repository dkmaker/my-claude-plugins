---
name: docs
description: Get official Claude Code documentation. Use when the user asks about Claude Code features OR when you need to create/implement plugins, skills, hooks, subagents, slash commands, or MCP servers. Always retrieve documentation BEFORE implementing any Claude Code feature. Topics include configuration, settings, deployment, and troubleshooting.
allowed-tools: Bash(claude-docs:*)
---

# Claude Code Documentation

This Skill provides access to official Claude Code documentation through the `claude-docs` CLI tool.

## Available Documentation

The plugin's session hook installs the `claude-docs` CLI globally, making it available as a command.

## When to Use This Skill

**User asks questions:**
- "How do I..." (create plugins, use hooks, configure settings, etc.)
- "Can Claude Code..." (feature capability questions)
- "What are..." (subagents, MCP servers, skills, etc.)
- "Tell me about..." (any Claude Code feature or concept)
- Questions about configuration, setup, deployment
- Troubleshooting Claude Code issues

**User requests implementation:**
- "Create/make a skill that..." - Get skill documentation first
- "Write a plugin for..." - Get plugin documentation first
- "Add a hook that..." - Get hook documentation first
- "Set up a slash command..." - Get command documentation first
- "Build a subagent..." - Get subagent documentation first
- ANY task involving Claude Code features - retrieve docs BEFORE implementing

**You recognize you need domain knowledge:**
- Before creating plugins, skills, hooks, subagents, or commands
- Before modifying Claude Code configuration
- Before answering questions about Claude Code capabilities
- When you're unsure about the correct way to implement a Claude Code feature

## How to Use the CLI Tool

### Step 1: Identify what documentation is needed

Determine the topic from the user's question:
- plugins, hooks, skills, mcp, agents, slash commands, settings, etc.

### Step 2: Load ALL related documentation

**Common topics and their related slugs (load ALL):**
- **plugins** → `plugins`, `plugin-marketplaces`, `plugins-reference`
- **hooks** → `hooks-guide`, `hooks`
- **skills** → `skills`
- **mcp** → `mcp`
- **agents/subagents** → `sub-agents`
- **slash commands** → `slash-commands`
- **settings** → `settings`
- **security/iam** → `security`, `iam`
- **monitoring** → `monitoring-usage`, `analytics`, `costs`

### Step 3: Use the CLI tool with Bash

**Load full documents (default approach):**
```bash
claude-docs get plugins
claude-docs get plugin-marketplaces
claude-docs get plugins-reference
```

**Browse document structure (if needed):**
```bash
# See list of all available docs
claude-docs list

# See table of contents for a specific document
claude-docs list plugins
```

**Search for specific topics:**
```bash
claude-docs search 'oauth'
claude-docs search 'environment variables'
```

**Get specific section (only if specifically requested):**
```bash
claude-docs get 'plugins#quickstart'
```

## Key Principles

1. **Load full documents first** - `get <slug>` loads the entire document including all sections
2. **Load ALL related docs** - Don't load just one if multiple exist for a topic
3. **Avoid anchors unless needed** - Full documents are usually better than subsections
4. **Be comprehensive** - When in doubt, load more documentation rather than less

## What NOT to Do

- ❌ Don't answer from training data without checking current docs
- ❌ Don't use anchors (`get <slug>#<anchor>`) unless user specifically requests a section
- ❌ Don't load just one doc when multiple related ones exist
- ❌ Don't search the web before checking official documentation

## Example Workflows

**User asks:** "How do I create a plugin with hooks?"

1. Identify topics: plugins + hooks
2. Load all related documentation:
   ```bash
   claude-docs get plugins
   claude-docs get plugin-marketplaces
   claude-docs get plugins-reference
   claude-docs get hooks-guide
   claude-docs get hooks
   ```
3. Provide comprehensive answer from loaded docs

**User asks:** "What are Skills?"

1. Identify topic: skills
2. Load documentation:
   ```bash
   claude-docs get skills
   ```
3. Explain Skills concept from documentation

**User asks:** "Can you help me set up MCP servers?"

1. Identify topic: mcp
2. Load documentation:
   ```bash
   claude-docs get mcp
   ```
3. Provide setup instructions from docs

## Remember

- The `claude-docs` CLI is installed globally (managed by the plugin's session hook)
- Always load documentation BEFORE implementing Claude Code features
- Documentation is locally cached and fast to retrieve
- Full documents are comprehensive - you usually don't need subsections
- After loading docs, provide answers based on official information

This Skill ensures you always have accurate, up-to-date Claude Code documentation when needed.
