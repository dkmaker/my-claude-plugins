# My Claude Plugins

A collection of Claude Code plugins and tools for enhancing development workflows.

**Repository:** [https://github.com/dkmaker/my-claude-plugins](https://github.com/dkmaker/my-claude-plugins)

## Repository Contents

This repository contains:

- **Claude Expert Plugin** - Expert knowledge system with comprehensive Claude Code documentation
- **Plugin Marketplace Configuration** - Enables plugin distribution and installation

### Claude Expert Plugin

**Expert knowledge system for Claude Code with comprehensive official documentation.**

**Location:** `claude-expert/`

**Features:**
- Complete documentation database (44 official sections)
- Intelligent search across all documentation
- MDX transformation pipeline (converts JSX/MDX to clean markdown)
- Smart caching system (10-38x performance improvement)
- Update workflow for keeping documentation current
- Built-in `claude-docs-cli` tool for documentation management

**See:** [claude-expert/README.md](claude-expert/README.md) for detailed documentation.

## Installation

### Add the Marketplace

```bash
/plugin marketplace add dkmaker/my-claude-plugins
```

### Install Plugins

```bash
# Install the Claude Expert plugin
/plugin install my-claude-plugins/claude-expert
```

Restart Claude Code to activate installed plugins.

## Repository Structure

```
claude-plugins/
├── .gitignore                    # Git ignore configuration
├── README.md                     # This file
├── .claude-plugin/
│   └── marketplace.json          # Plugin marketplace configuration
└── claude-expert/                # Claude Expert plugin
    ├── README.md                 # Plugin documentation
    ├── .claude-plugin/
    │   └── plugin.json           # Plugin metadata
    ├── agents/
    │   └── claude-docs.md        # Agent for documentation queries
    ├── hooks/
    │   ├── hooks.json            # Hook configuration
    │   └── scripts/
    │       └── sessionstart.sh   # Session initialization script
    ├── scripts/
    │   ├── claude-docs.sh        # Documentation CLI tool
    │   └── claude-docs-urls.json # Documentation URLs
    └── skills/
        └── docs/
            └── SKILL.md          # Skill definition
```

## Usage

Once the plugin is installed, it provides several features:

### Automatic Documentation Assistance

Ask Claude Code questions about itself, and the Claude Expert plugin will automatically activate:

```
"How do I create a plugin?"
"What MCP servers work with Claude Code?"
"Can Claude Code integrate with VS Code?"
"How do subagents work?"
```

### Manual CLI Access

You can also use the documentation CLI tool directly:

```bash
# Navigate to plugin directory
cd ~/.claude/plugins/my-claude-plugins/claude-expert/scripts/

# Search documentation
./claude-docs.sh search 'oauth'

# Get full documentation section
./claude-docs.sh get plugins

# List all available docs
./claude-docs.sh list

# Check for documentation updates
./claude-docs.sh update status
```

See [claude-expert/README.md](claude-expert/README.md) for complete CLI documentation.

## Documentation Coverage

The Claude Expert plugin includes comprehensive documentation across 7 major categories:

1. **Getting started** - Overview, quickstart, common workflows
2. **Outside of the terminal** - VS Code, JetBrains, web interfaces, CI/CD
3. **Build with Claude Code** - Sub-agents, plugins, skills, hooks, MCP
4. **Deployment** - Cloud providers (AWS, Azure, GCP), networking, containers
5. **Administration** - Setup, security, IAM, monitoring, costs
6. **Settings** - Configuration for terminal, models, memory, UI
7. **Reference** - CLI reference, commands, hooks API
8. **Resources** - Legal and compliance

**Total:** 44 comprehensive documentation sections

## Development

### Adding New Plugins

To add a new plugin to this marketplace:

1. Create a new directory for your plugin
2. Add plugin metadata in `.claude-plugin/plugin.json`
3. Update `.claude-plugin/marketplace.json` to register the plugin
4. Commit and push changes

### Plugin Structure

Each plugin should follow this structure:

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json          # Plugin metadata
├── README.md                # Plugin documentation
├── agents/                  # Optional: custom agents
├── hooks/                   # Optional: event hooks
└── skills/                  # Optional: skills
```

## Requirements

- **Claude Code** - Latest version recommended
- **Dependencies** - curl, jq, diff, node (for MCP table parsing)
- **Disk space** - Approximately 2MB for plugins and documentation

## Contributing

Contributions are welcome! Please:

1. Fork the repository at [https://github.com/dkmaker/my-claude-plugins](https://github.com/dkmaker/my-claude-plugins)
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Support

For issues or questions:

- Check the plugin documentation in `claude-expert/README.md`
- Use the Claude Expert plugin to search documentation
- Review marketplace configuration in `.claude-plugin/marketplace.json`

## License

See individual plugin directories for specific licensing information.