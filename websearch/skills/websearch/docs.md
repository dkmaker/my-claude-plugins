# Documentation Lookup

## Commands

```bash
# Quick documentation lookup (default)
websearch "how to use X in Y"

# Node.js ecosystem (filters to nodejs.org, MDN, npmjs.com)
websearch -p nodejs "express middleware setup"

# Python ecosystem (filters to docs.python.org, pypi.org, realpython.com)
websearch -p python "sqlalchemy async session"

# Find official docs via reasoning
websearch -m reason "correct way to configure X in Y"

# Find GitHub README/docs for a library
websearch -p github "library-name"
```

## Guidelines

- Use `-p nodejs` or `-p python` for ecosystem-specific queries — filters to authoritative sources
- Use `-m reason` for "how should I configure X" questions needing analysis
- Use `-p github` to find a library's repo and README
- Default `-m ask` works well for straightforward "how to use X" questions
- `--include-sources` when you need to cite documentation URLs
- For working code snippets and usage examples, also see [examples.md](examples.md)
- For **version-specific library API docs**, prefer Context7 (`resolve-library-id` → `query-docs`) over websearch — it pulls from official docs and is more accurate for specific API questions
