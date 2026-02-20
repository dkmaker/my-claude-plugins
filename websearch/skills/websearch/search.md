# General Web Search

## Commands

```bash
# Quick answer (default mode: ask)
websearch "your question here"

# Deep research (slower, more thorough)
websearch -m research "complex topic"

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
- `-m research` for comprehensive deep-dive topics (slow, 30s+)
- `-m search` when you need URLs/links rather than synthesized answers
- `--include-sources` when citations matter
- `--no-cache` for time-sensitive queries
