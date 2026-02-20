# Patterns & Best Practices

## Commands

```bash
# Analyze tradeoffs between approaches (recommended)
websearch -m reason "tradeoffs between X vs Y for Z"

# Find real-world implementations
websearch -p github "pattern-name implementation language"

# Find community consensus
websearch "recommended approach for X"
```

## Guidelines

- `-m reason` for comparison/tradeoff questions — structured analysis
- `-p github` to find real implementations demonstrating a pattern
- Prefer multiple focused `-m reason` queries over a single `-m research` call
- Frame queries as tradeoff questions: "X vs Y" or "when to use X over Y"
