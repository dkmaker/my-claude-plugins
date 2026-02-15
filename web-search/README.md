# web-search-skill

Web search using Perplexity AI for intelligent search, research, reasoning, and question answering.

## Features

- **Multiple modes**: Ask, search, reason, research
- **Automatic time detection**: "latest", "today", "this week" enriched automatically
- **Result archiving**: Save valuable searches for future reference
- **Resumable agent**: Continue conversations with follow-up questions
- **Structured storage**: Organized markdown files with frontmatter metadata

## Installation

```bash
/plugin install web-search-skill@my-claude-plugins
```

## Prerequisites

Requires the Perplexity API via MCP. Make sure you have:
- Perplexity MCP server configured
- `PERPLEXITY_API_KEY` environment variable set

## Usage

The skill activates automatically when you ask Claude to search, research, or ask questions about topics.

### Automatic Invocation

```
"Search for latest Claude Code features"
"Research the history of quantum computing"
"What are the best practices for React hooks?"
```

### Manual Invocation

```
/search ask what is the capital of France
/search search latest AI news
/search reason why is the sky blue
/search research history of the internet
```

## Search Modes

| Mode | Purpose | Example |
|------|---------|---------|
| **ask** | Quick Q&A | "What is photosynthesis?" |
| **search** | Find information | "Latest electric car models" |
| **reason** | Deep analysis | "Why did the Roman Empire fall?" |
| **research** | Comprehensive investigation | "History of space exploration" |

## Time Span Detection

The skill automatically detects temporal queries:
- "latest" → recency=day
- "today" → recency=day
- "this week" → recency=week
- "this month" → recency=month
- "this year" → recency=year

## Result Archiving

After each search, you can:
1. **Expand** - Ask follow-up questions
2. **Save** - Archive the result to `~/search_results/`
3. **Done** - Finish the search

Saved results include:
- Frontmatter metadata (query, mode, date, time_span)
- Full formatted response
- Searchable index in `CLAUDE.md`

### Managing Saved Results

```bash
# List all saved searches
bash ~/.claude/skills/search/scripts/list.sh ~/search_results

# Update the index
bash ~/.claude/skills/search/scripts/update-index.sh ~/search_results
```

## How It Works

The skill delegates to a `web-search` subagent that:
1. Detects search mode and time span
2. Executes the search via Perplexity API
3. Formats the response
4. Offers to expand, save, or finish

The subagent is **resumable** - you can continue the conversation or save results later.

## Storage Structure

```
~/search_results/
├── CLAUDE.md                           # Auto-generated index
├── 2026-02-15-latest-ai-news.md       # Saved search
├── 2026-02-14-quantum-computing.md    # Saved search
└── ...
```

Each saved result has frontmatter:
```markdown
---
query: latest AI news
mode: search
date: 2026-02-15
time_span: day
---
```

## Scripts Included

- `list.sh` - List all saved searches with metadata
- `slug.sh` - Generate slugs from queries
- `update-index.sh` - Rebuild CLAUDE.md index

## License

MIT
