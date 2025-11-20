# Claude Expert Plugin

Expert knowledge system that gives Claude Code access to its own official documentation.

## What This Plugin Does

When you ask Claude Code questions about itself (features, plugins, hooks, etc.), this plugin ensures Claude gets accurate, up-to-date answers from official documentation instead of relying on outdated training data.

## How It Works

This plugin has three main components that work together:

### 1. **Skill** (`skills/docs/`)

The **Skill** is what gets activated when you ask Claude Code questions. Think of it as a trigger that recognizes when you need documentation help.

- **What it does:** Detects when you're asking about Claude Code features
- **When it activates:** Questions like "How do I create a plugin?" or "Can Claude Code do X?"
- **What it does next:** Uses the CLI tool directly to load documentation into context

### 2. **CLI Tool** (`scripts/claude-docs.sh`)

The **CLI Tool** is a bash script that manages the actual documentation database.

- **What it does:** Downloads, caches, and searches documentation
- **Features:**
  - Search across all documentation
  - Retrieve specific sections
  - Transform MDX/JSX to readable markdown
  - Smart caching for speed
- **Can be used manually:** You can run it yourself from the command line
- **Used by Skill:** The Skill calls this tool via Bash to load documentation

### 3. **Session Hook** (`hooks/scripts/sessionstart.sh`)

The **Hook** runs when you start a new Claude Code session.

- **What it does:** Adds `claude-docs.sh` to your PATH and tells Claude to use the Skill for documentation questions
- **When it runs:** Automatically on session start
- **Effect:** Makes the CLI tool available as a simple command and injects context instructions

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
Skill uses CLI tool (claude-docs.sh) via Bash
       ↓
CLI tool searches documentation database
       ↓
Documentation loaded into context
       ↓
Claude presents answer to user
```

## File Structure

```
claude-expert/
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata
├── README.md                    # This file
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

A Skill is an instruction set that tells Claude when and how to handle specific types of requests. The `docs` skill recognizes documentation questions and uses the CLI tool to load relevant documentation.

### What is a Hook?

A Hook is a script that runs in response to events. The `SessionStart` hook runs when you start Claude Code, adding the CLI tool to your PATH and instructing Claude to use this plugin for documentation questions.

### What is the CLI Tool?

The CLI tool is a standalone bash script that manages documentation. It downloads docs, caches them, searches them, and transforms them into readable format. Both you and the Skill can use it.

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
