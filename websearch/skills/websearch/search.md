# General Web Search

## Commands

```bash
# Quick answer (default mode: ask)
websearch "your question here"

# Reasoning with chain-of-thought
websearch -m reason "question requiring analysis"

# Search for links/results only
websearch -m search "topic"

# Brave web search (alternative provider)
websearch --provider brave "query"
```

## Guidelines

- `-m ask` (default) for quick factual questions
- `-m reason` when the answer requires analysis or comparison
- `-m search` when you need URLs/links rather than synthesized answers
- Prefer multiple `-m ask`/`-m reason` calls over `-m research` (see SKILL.md)
- `--include-sources` when citations matter
- `--no-cache` for time-sensitive queries
