---
name: docs
description: Get official Claude Code documentation. Use when the user asks about Claude Code features OR when you need to create/implement plugins, skills, hooks, subagents, slash commands, or MCP servers. Always retrieve documentation BEFORE implementing any Claude Code feature. Topics include configuration, settings, deployment, and troubleshooting.
allowed-tools: Task
---

# Claude Code Documentation Finder

This Skill helps you find and retrieve official Claude Code documentation by delegating to a specialized documentation retrieval agent.

## When to Use This Skill

Activate this Skill when:

**The user asks questions:**
- "How do I..." (create plugins, use hooks, configure settings, etc.)
- "Can Claude Code..." (feature capability questions)
- "What are..." (subagents, MCP servers, skills, etc.)
- "Tell me about..." (any Claude Code feature or concept)
- Questions about configuration, setup, deployment
- Troubleshooting Claude Code issues

**The user requests implementation:**
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

## How This Skill Works

This Skill uses the `claude-expert:claude-docs` agent to retrieve documentation. The agent:
1. Lists all available documentation sections
2. Searches and retrieves relevant documentation
3. Can compare documentation with actual project configuration
4. Provides accurate answers from official sources

## Instructions

When this Skill is activated:

1. **Use the Task tool** to invoke the documentation agent:
   ```
   Use Task tool with:
   - subagent_type: "claude-expert:claude-docs"
   - description: Brief description of what documentation is needed
   - prompt: The user's question with full context
   ```

2. **Pass the complete user question** to the agent with any relevant context

3. **Let the agent handle all documentation retrieval** - it will:
   - Search the documentation
   - Retrieve relevant sections
   - Check actual configuration if needed
   - Provide comprehensive answers

4. **Present the agent's findings** to the user clearly

## Example Usage

**User asks:** "How do I create a plugin with hooks?"

**Your response:**
```
I'll use the documentation agent to find the official information about creating plugins with hooks.

[Invoke Task tool with subagent_type="claude-expert:claude-docs"]
```

**User asks:** "What environment variables are available in SessionStart hooks?"

**Your response:**
```
Let me retrieve the documentation about SessionStart hooks and environment variables.

[Invoke Task tool with subagent_type="claude-expert:claude-docs"]
```

## What NOT to Do

L **Don't answer from your training data** - Always use the agent to get current documentation
L **Don't try to search documentation yourself** - The agent has specialized tools for this
L **Don't use other tools** - Only use Task to invoke the documentation agent
L **Don't skip the agent** - Even if you think you know the answer, verify with current docs

## Why Use a Subagent?

The documentation agent:
- Has access to all official Claude Code documentation sections
- Uses `claude-docs.sh` CLI tool for accurate, transformed documentation
- Can search, retrieve, and compare with actual configuration
- Provides up-to-date information (documentation may have changed since your training)
- Knows about known bugs (like CLAUDE_ENV_FILE in plugin hooks)
- Can check GitHub issues for problems not in official docs

## Remember

- **Always delegate** to the agent - it's specialized for documentation retrieval
- **Pass full context** - include the user's complete question and any relevant details
- **Trust the agent's response** - it has access to current, official documentation
- **Keep it simple** - your job is to recognize documentation questions and route them to the agent

This Skill ensures users always get accurate, up-to-date information from official Claude Code documentation.
