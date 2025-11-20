# Claude Expert Plugin

Expert knowledge system that gives Claude Code access to its own official documentation.

## What This Plugin Does

When you ask Claude Code questions about itself (features, plugins, hooks, etc.), this plugin ensures Claude gets accurate, up-to-date answers from official documentation instead of relying on outdated training data.

## How It Works

This plugin has four main components that work together:

### 1. **Skill** (`skills/docs/`)

The **Skill** is what gets activated when you ask Claude Code questions. Think of it as a trigger that recognizes when you need documentation help.

- **What it does:** Detects when you're asking about Claude Code features
- **When it activates:** Questions like "How do I create a plugin?" or "Can Claude Code do X?"
- **What it does next:** Hands off to the Agent to find the answer

### 2. **Agent** (`agents/claude-docs.md`)

The **Agent** is a specialized subagent that knows how to search and retrieve documentation.

- **What it does:** Searches through all 44 sections of Claude Code documentation
- **How it works:** Uses the CLI tool to find relevant information
- **What it returns:** Accurate answers from official sources

### 3. **CLI Tool** (`scripts/claude-docs.sh`)

The **CLI Tool** is a bash script that manages the actual documentation database.

- **What it does:** Downloads, caches, and searches documentation
- **Features:**
  - Search across all documentation
  - Retrieve specific sections
  - Transform MDX/JSX to readable markdown
  - Smart caching for speed
- **Can be used manually:** You can run it yourself from the command line

### 4. **Session Hook** (`hooks/scripts/sessionstart.sh`)

The **Hook** runs when you start a new Claude Code session.

- **What it does:** Tells Claude to use this plugin for documentation questions
- **When it runs:** Automatically on session start
- **Effect:** Adds the CLI tool to your PATH and injects context instructions

## Installation

```bash
# Add the marketplace
/plugin marketplace add dkmaker/my-claude-plugins

# Install this plugin
/plugin install my-claude-plugins/claude-expert
```

Restart Claude Code after installation.

## Usage

### Automatic (Recommended)

Just ask Claude Code questions naturally:

```
"How do I create a hook?"
"What MCP servers are available?"
"Can Claude Code integrate with VS Code?"
"How do subagents work?"
```

The plugin automatically activates and provides accurate answers.

### Manual CLI Usage

You can also use the documentation CLI directly:

```bash
cd ~/.claude/plugins/my-claude-plugins/claude-expert/scripts/

# Search for a topic
./claude-docs.sh search 'oauth'

# Get a specific documentation section
./claude-docs.sh get plugins

# List all available documentation
./claude-docs.sh list

# Show structure of a document
./claude-docs.sh list plugins
```

## Documentation Coverage

The plugin includes all official Claude Code documentation:

- **Getting started** - Overview, quickstart, workflows
- **IDE integration** - VS Code, JetBrains, web UI
- **Building** - Plugins, skills, hooks, MCP, subagents
- **Deployment** - AWS, Azure, GCP, containers
- **Administration** - Security, IAM, monitoring
- **Settings** - Configuration options
- **Reference** - CLI commands, APIs

**Total: 44 documentation sections**

## How The Components Connect

```
User asks question
       ↓
Skill detects it's about Claude Code
       ↓
Skill invokes Agent (claude-expert:claude-docs)
       ↓
Agent uses CLI tool (claude-docs.sh)
       ↓
CLI tool searches documentation database
       ↓
Agent returns answer
       ↓
Claude presents it to user
```

## File Structure

```
claude-expert/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata
├── README.md                    # This file
├── agents/
│   └── claude-docs.md           # Documentation search agent
├── hooks/
│   ├── hooks.json               # Hook configuration
│   └── scripts/
│       └── sessionstart.sh      # Session startup script
├── scripts/
│   ├── claude-docs.sh           # Documentation CLI tool
│   └── claude-docs-urls.json    # Documentation URL mappings
└── skills/
    └── docs/
        └── SKILL.md             # Skill definition
```

## Key Concepts

### What is a Skill?

A Skill is an instruction set that tells Claude when and how to handle specific types of requests. The `docs` skill recognizes documentation questions and delegates to the specialized agent.

### What is an Agent?

An Agent is a subagent - a specialized instance of Claude with specific tools and instructions. The `claude-docs` agent is optimized for searching and retrieving documentation.

### What is a Hook?

A Hook is a script that runs in response to events. The `SessionStart` hook runs when you start Claude Code, setting up the environment and instructing Claude to use this plugin.

### What is the CLI Tool?

The CLI tool is a standalone bash script that manages documentation. It can download docs, cache them, search them, and transform them into readable format. Both the agent and you can use it.

## Maintenance

### Update Documentation

Check for new documentation versions:

```bash
cd ~/.claude/plugins/my-claude-plugins/claude-expert/scripts/
./claude-docs.sh update
```

### Clear Cache

If documentation seems stale:

```bash
./claude-docs.sh cache clear
./claude-docs.sh cache warm
```

## Requirements

- **Claude Code** - Latest version
- **System tools** - bash, curl, jq, diff
- **Disk space** - ~2MB

## Support

For issues:
- Check documentation: `./claude-docs.sh search '<topic>'`
- List all docs: `./claude-docs.sh list`
- Get help: `./claude-docs.sh help`

## Version

**1.0.0** - Initial release

## License

Provides access to official Claude Code documentation. See Anthropic's terms of service.
