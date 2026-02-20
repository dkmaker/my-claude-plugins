# Code Examples & Snippets

Find real-world code examples, implementation patterns, and working snippets to learn from or adapt.

## Commands

```bash
# Find implementation examples on GitHub (code search)
websearch -p github -m code "how to implement X in language"

# Find examples in specific file types
websearch -p github -m code --gh-extension py "fastapi middleware example"
websearch -p github -m code --gh-extension ts "zod validation schema"

# Find examples within a specific library's codebase
websearch -p github -m code --gh-repo expressjs/express "error handling middleware"

# Find example repos (look for repos with "example" or "sample" in name)
websearch -p github --gh-topic example --gh-language go "grpc server"

# Find usage examples via web search (blogs, tutorials, Stack Overflow)
websearch "X code example with Y"
websearch -m reason "working example of X pattern in Y language"

# Find config file examples
websearch -p github -m code --gh-filename "docker-compose.yml" "postgres redis"
websearch -p github -m code --gh-filename "tsconfig.json" "path aliases monorepo"
websearch -p github -m code --gh-filename ".github/workflows" "deploy to kubernetes"

# Find test files as usage examples (tests are great documentation)
websearch -p github -m code --gh-path test "library-name usage"
```

## Guidelines

- `-m code` searches actual source code — great for finding how others solved a problem
- `--gh-extension` narrows to specific languages (py, ts, go, rs, etc.)
- `--gh-filename` finds config files, CI workflows, dockerfiles by name
- `--gh-path test` searches inside test directories — tests often show idiomatic usage
- `--gh-repo` searches within a specific repo — useful for finding examples in a library's own codebase
- Combine with `-m ask` or `-m reason` to get explained examples from web articles
- For config/setup examples, search for the exact filename (docker-compose.yml, pyproject.toml, etc.)
- For **official library code examples**, use Context7 (`resolve-library-id` → `query-docs`) — it returns examples straight from the library's own documentation
