---
name: research
description: Conducts structured research on topics using the research CLI with multiple provider support. Use when the user asks to research, investigate, or explore a topic in depth, or when gathering information from multiple sources with citations.
allowed-tools: Bash, Read
---

# Research Skill

You have access to a research CLI tool that queries multiple research providers (Perplexity, etc.) with real-time web search capabilities.

## Using the Research CLI

The CLI is located at: `${CLAUDE_PLUGIN_ROOT}/skills/research/lib/index.js`

### Basic Usage

```bash
node ${CLAUDE_PLUGIN_ROOT}/skills/research/lib/index.js "your research query"
```

### Available Profiles

| Profile | Use Case |
|---------|----------|
| `general` | General-purpose research on any topic (default) |
| `code` | Code examples, implementations, programming solutions |
| `docs` | Official documentation and API references |
| `troubleshoot` | Errors, bugs, debugging, and known issues |

### Profile Selection

```bash
# General research (default)
node ${CLAUDE_PLUGIN_ROOT}/skills/research/lib/index.js "quantum computing basics"

# Code examples
node ${CLAUDE_PLUGIN_ROOT}/skills/research/lib/index.js --profile code "React hooks examples"

# Documentation lookup
node ${CLAUDE_PLUGIN_ROOT}/skills/research/lib/index.js --profile docs "Node.js fs.readFile API"

# Troubleshooting errors
node ${CLAUDE_PLUGIN_ROOT}/skills/research/lib/index.js --profile troubleshoot "ECONNREFUSED error Node.js"
```

### Additional Options

```bash
# Filter by recency
node ${CLAUDE_PLUGIN_ROOT}/skills/research/lib/index.js --recency week "topic"

# Get JSON output for parsing
node ${CLAUDE_PLUGIN_ROOT}/skills/research/lib/index.js --json "topic"
```

## Research Methodology

### 1. Clarify the Research Question

Before running the CLI:
- Determine what type of information is needed
- Choose the appropriate profile
- Identify any constraints (time period, sources)

If unclear, ask the user to clarify.

### 2. Select the Right Profile

- **General questions**: Use `general` profile
- **How to implement X?**: Use `code` profile
- **What does this API do?**: Use `docs` profile
- **Why is this failing?**: Use `troubleshoot` profile

### 3. Synthesize and Present

After running the CLI, structure output as:

**Summary**: Brief overview of key findings

**Key Findings**:
- Finding with supporting evidence and source
- Additional findings...

**Sources**: List sources from the CLI output with URLs

**Limitations**: Note any gaps or areas needing further research

## Requirements

- `PERPLEXITY_API_KEY` must be set in the user's environment
- Node.js 18+ required (for native fetch)
