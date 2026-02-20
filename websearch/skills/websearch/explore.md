# GitHub Code & Repo Exploration

## Commands

```bash
# Search for repositories
websearch -p github "description of what you're looking for"

# Filter by language and quality
websearch -p github --gh-language typescript --gh-stars '>500' "state management"

# Search code across GitHub
websearch -p github -m code "specific function or pattern"

# Search code in specific file types
websearch -p github -m code --gh-extension go "pattern to find"

# Search within a specific repo
websearch -p github -m code --gh-repo owner/repo "function name"

# Find repos by topic
websearch -p github --gh-topic cli --gh-language rust "search tool"

# Recently active projects
websearch -p github --gh-pushed '>2025-01-01' --gh-stars '>100' "topic"
```

## Guidelines

- Default mode (`repos`) to find repositories
- `-m code` to search actual source code across GitHub
- Combine `--gh-language`, `--gh-stars`, `--gh-topic` for precise filtering
- `--gh-sort stars` for most popular results
- `--gh-pushed` for actively maintained projects
