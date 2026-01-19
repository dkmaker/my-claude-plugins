# Knowledge Plugin - Development Guide

## Overview

The Knowledge plugin provides structured research workflows with persistent storage for Claude Code. It includes a SessionStart hook, a research skill, and a Node.js CLI with multi-provider support.

## Architecture

### Plugin Structure

```
knowledge/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── hooks/
│   ├── hooks.json               # SessionStart hook config
│   └── scripts/
│       └── sessionstart.sh      # Injects research context
├── skills/
│   └── research/
│       ├── SKILL.md             # Skill definition
│       └── lib/                 # Research CLI (Node.js)
│           ├── package.json     # npm project, Node 18+
│           ├── index.js         # CLI entry point
│           ├── profiles.json    # Research profiles
│           ├── providers/       # Provider implementations
│           │   ├── index.js     # Provider registry
│           │   ├── base.js      # Base provider + schemas
│           │   └── perplexity.js # Perplexity implementation
│           └── storage/         # Persistence layer
│               ├── index.js     # Storage paths and init
│               ├── utils.js     # ID generation, thinking stripping
│               ├── entries.js   # Entry CRUD operations
│               └── categories.js # Category CRUD operations
├── README.md
└── CLAUDE.md                    # This file
```

## Key Concepts

### Providers

**Provider Architecture**: Extensible system for multiple research APIs
- **Base Provider** (`providers/base.js`): Abstract interface with `ask()` and `search()` methods
- **Perplexity Provider** (`providers/perplexity.js`): Implements Perplexity API with structured responses
- **Future Providers**: Tavily, Claude Research, etc.

**Provider Selection**: Profiles specify which provider to use (currently all use Perplexity)

### Profiles

**Profile-Based Research**: Task-oriented research modes (not provider-specific)

| Profile | Model | Purpose |
|---------|-------|---------|
| `general` | sonar | General-purpose research (default) |
| `code` | sonar-reasoning-pro | Code examples with step-by-step reasoning |
| `docs` | sonar | Official documentation and API references |
| `troubleshoot` | sonar | Error messages, bugs, debugging |

**Profile Configuration** (`profiles.json`):
```json
{
  "profile-name": {
    "provider": "perplexity",
    "model": "sonar",
    "description": "When to use this profile",
    "system": "LLM system prompt (role definition)",
    "prompt": "User message template with {{QUERY}} placeholder",
    "options": {
      "search_recency_filter": "week",
      "search_domain_filter": ["domain.com"]
    }
  }
}
```

### Structured Responses

**JSON Schema Response Format**: All queries return structured JSON

**Schema**:
```json
{
  "title": "Auto-generated title (max 80 chars)",
  "content": "Full response with [1], [2] citation refs",
  "examples": [
    {
      "description": "What this example shows",
      "code": "code snippet",
      "language": "javascript"
    }
  ]
}
```

**Implementation**:
- **Base System Prompt** (`BASE_SYSTEM_PROMPT` in `providers/base.js`): Instructions for structured JSON output
- **Profile System Prompt**: Appended to base prompt for role-specific guidance
- **Response Format**: `response_format.json_schema` sent to Perplexity API

### Thinking Separation

**Reasoning Models**: `sonar-reasoning-pro` outputs `<think>...</think>` tags

**Handling**:
1. Strip thinking tags from response (`stripThinking()` in `storage/utils.js`)
2. Store separately: `thinking` field and `content` field
3. Default output: Clean content only
4. `--show-thinking` flag: Display reasoning process

**Benefits**: Clean output, preserved for debugging, no data loss

### Persistence System

**Storage Location**: `~/.local/share/knowledge/` (override with `KNOWLEDGE_DATA_DIR`)

**Files**:
- `categories.json`: Category definitions with 5-char IDs
- `unsaved.json`: All research results (auto-saved)
- `library.json`: Curated entries mapped to categories

**Entry Schema**:
```json
{
  "id": "xp48e",
  "category_id": "kunhu",
  "query": "original query",
  "profile": "code",
  "model": "sonar-reasoning-pro",
  "provider": "perplexity",
  "scope": {
    "type": "repository|general",
    "path": "/path/to/repo"
  },
  "title": "Generated title",
  "content": "Response with [n] refs",
  "thinking": "Reasoning process or null",
  "examples": [],
  "sources": [
    {"number": 1, "title": "...", "url": "...", "snippet": "..."}
  ],
  "usage": {"input_tokens": 50, "output_tokens": 280},
  "created_at": "ISO8601",
  "curated_at": "ISO8601"
}
```

**Category Schema**:
```json
{
  "id": "kunhu",
  "slug": "python-basics",
  "description": "Category description",
  "rules": "When to apply this category",
  "created_at": "ISO8601"
}
```

### Short ID Generation

**Character Set**: `abcdefghjkmnpqrstuvwxyz23456789` (32 chars)
- Excludes confusing characters: `i, l, o, 0, 1`
- 5 characters = 32^5 = 33,554,432 combinations
- Collision detection with retry (max 100 attempts)

**Implementation**: `generateId()` in `storage/utils.js`

## CLI Commands

### Research Queries

```bash
# General research (default profile, auto-saved to unsaved.json)
node index.js "query here"

# Use specific profile
node index.js --profile code "React hooks"
node index.js --profile docs "Node.js fs.readFile"
node index.js --profile troubleshoot "ECONNREFUSED error"

# Save as general (not repository-bound)
node index.js --general "query"

# Show reasoning process
node index.js --profile code --show-thinking "query"

# Additional options
node index.js --recency week "topic"
node index.js --domains "arxiv.org,github.com" "topic"
node index.js --max-tokens 500 "query"
node index.js --json "query"  # Full JSON output
```

### Storage Management

```bash
# List all categories
node index.js --categories

# Create category
node index.js --create-category slug-name

# List unsaved entries
node index.js --unsaved
node index.js --unsaved --local  # Current repo only

# List curated library entries
node index.js --library
node index.js --library --category kunhu  # Filter by category
node index.js --library --local           # Current repo only

# Curate entry (move from unsaved to library)
node index.js --curate xp48e --category kunhu

# Info commands
node index.js --list-profiles
node index.js --list-providers
node index.js --help
```

## Workflow

### Research Flow

1. **User queries** → CLI executes with profile
2. **Provider API call** → Returns structured JSON with title/content/examples
3. **Thinking stripped** → Separated and stored, hidden by default
4. **Auto-saved** → Entry created in `unsaved.json` with short ID
5. **User curates** → Moves entry to `library.json` with category mapping

### Scope Tracking

- **Repository-bound** (default): Saved with current working directory path
- **General** (`--general` flag): Not bound to specific repo, `scope.path = null`
- **Filtering** (`--local` flag): Show only entries from current repo

## Environment Variables

| Variable | Purpose | Required |
|----------|---------|----------|
| `PERPLEXITY_API_KEY` | Perplexity API authentication | Yes (for Perplexity provider) |
| `KNOWLEDGE_DATA_DIR` | Override storage directory | No (defaults to `~/.local/share/knowledge`) |

## Development

### Testing Locally

```bash
# Test CLI directly
cd knowledge/skills/research/lib
node index.js --help

# Test with Claude Code
claude --plugin-dir ./knowledge
```

### Adding a New Provider

1. Create `providers/newprovider.js` extending `BaseProvider`
2. Implement `ask()` method (and optionally `search()`)
3. Add to `providers/index.js` registry
4. Create profiles using the new provider in `profiles.json`

**Example**:
```javascript
class TavilyProvider extends BaseProvider {
  static envKey = 'TAVILY_API_KEY';
  static name = 'tavily';
  static displayName = 'Tavily Search';

  async ask(query, options = {}) {
    // Implement Tavily API call
  }
}
```

### Adding a New Profile

Edit `profiles.json`:
```json
{
  "new-profile": {
    "provider": "perplexity",
    "model": "sonar",
    "description": "Profile purpose",
    "system": "LLM role instructions",
    "prompt": "Query template with {{QUERY}}"
  }
}
```

## Technical Details

### Dependencies

**Zero external dependencies** - Uses Node.js built-ins:
- `fetch` (Node 18+): HTTP requests
- `fs`: File operations
- `path`: Path manipulation
- `crypto`: Random ID generation (via `Math.random()`)

### Structured Response Implementation

**Base System Prompt** (`BASE_SYSTEM_PROMPT`):
- Defines JSON schema structure
- Instructs model on title/content/examples format
- Prepended to all profile system prompts

**Perplexity API `response_format`**:
- Sends JSON schema to enforce structure
- First request with new schema: 10-30 second delay
- Subsequent requests: Fast

**Parsing**:
1. Strip `<think>` tags
2. Parse JSON from content
3. Fallback to raw content if parsing fails

### Storage Files

**Atomic writes**: Files written with `JSON.stringify(data, null, 2)`
**Initialization**: Files created with empty structures on first access
**Error handling**: Missing files trigger auto-initialization

## Common Tasks

### View Research History

```bash
# All unsaved from current repo
node index.js --unsaved --local

# All curated entries
node index.js --library
```

### Organize Knowledge

```bash
# Create categories for organization
node index.js --create-category react-hooks
node index.js --create-category node-apis

# Curate entries
node index.js --unsaved
node index.js --curate xp48e --category kunhu
```

### Debug Reasoning

```bash
# Show thinking process
node index.js --profile code --show-thinking "complex algorithm"
```

## Integration with Claude Code

### Skill Invocation

The `knowledge:research` skill is model-invoked. Claude automatically uses it when:
- User asks to "research X"
- User requests "investigate Y"
- User wants "information about Z"

### Hook Injection

SessionStart hook (`hooks/scripts/sessionstart.sh`) injects context telling Claude:
- When to use the research skill
- That the skill provides comprehensive research workflows

### Allowed Tools

Skill restricts Claude to: `Bash`, `Read`
- Can execute the research CLI
- Can read skill documentation and supporting files
- Cannot edit files or run arbitrary commands

## Future Enhancements

- Additional providers (Tavily, Claude Research API)
- More profiles based on telemetry
- Search/filter within library
- Export to markdown/PDF
- Auto-categorization with LLM
