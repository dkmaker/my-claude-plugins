# Knowledge Plugin

A Claude Code plugin for structured research workflows with persistent knowledge storage.

## Features

- **SessionStart Hook**: Injects research guidance into Claude's context
- **Research Skill**: Model-invoked skill with CLI-based research (`knowledge:research`)
- **Multi-Provider Support**: Extensible provider architecture (Perplexity supported)
- **Profile-Based Research**: 4 specialized profiles (general, code, docs, troubleshoot)
- **Structured Responses**: Auto-generated titles, content, and code examples
- **Knowledge Persistence**: Save, categorize, and curate research results

## Installation

### Local Development

```bash
claude --plugin-dir ./knowledge
```

### From Marketplace

```bash
/plugin install knowledge@my-claude-plugins
```

### Requirements

- Node.js 18+ (for native fetch)
- `PERPLEXITY_API_KEY` environment variable

## Usage

### As a Skill

The plugin activates automatically when you ask Claude to research:

```
Research the current state of WebAssembly support in browsers
```

Claude uses the `knowledge:research` skill to query the research CLI and present findings.

### Direct CLI Usage

```bash
# General research
node skills/research/lib/index.js "What is quantum computing?"

# Code examples
node skills/research/lib/index.js --profile code "React hooks patterns"

# Documentation lookup
node skills/research/lib/index.js --profile docs "Node.js fs API"

# Troubleshooting
node skills/research/lib/index.js --profile troubleshoot "ECONNREFUSED error"
```

## Profiles

| Profile | Use Case |
|---------|----------|
| `general` | General-purpose research (default) |
| `code` | Code examples with reasoning |
| `docs` | Official documentation |
| `troubleshoot` | Errors and debugging |

## Knowledge Storage

Research results are automatically saved to `~/.local/share/knowledge/`:

```bash
# List unsaved entries
node skills/research/lib/index.js --unsaved

# Create category
node skills/research/lib/index.js --create-category react-patterns

# List categories
node skills/research/lib/index.js --categories

# Curate entry to category
node skills/research/lib/index.js --curate <entry-id> --category <category-id>

# View library
node skills/research/lib/index.js --library

# Filter to current repo only
node skills/research/lib/index.js --library --local
```

### Environment Variables

- `PERPLEXITY_API_KEY`: Required for Perplexity provider
- `KNOWLEDGE_DATA_DIR`: Override storage directory (default: `~/.local/share/knowledge`)

## Structure

```
knowledge/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── hooks/
│   ├── hooks.json           # Hook configuration
│   └── scripts/
│       └── sessionstart.sh  # Injects research context
├── skills/
│   └── research/
│       ├── SKILL.md         # Research methodology skill
│       └── lib/             # Research CLI
│           ├── index.js     # CLI entry point
│           ├── profiles.json
│           ├── providers/   # Provider implementations
│           └── storage/     # Persistence layer
└── README.md
```

## Development

Test the hook:

```bash
./knowledge/hooks/scripts/sessionstart.sh
```

Test the CLI:

```bash
cd knowledge/skills/research/lib
node index.js --help
```
