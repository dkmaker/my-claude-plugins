# Dependency Management

## Commands

```bash
# GitHub issues for dependency conflicts
websearch -p github -m issues "package-name version conflict error"

# Search in a specific repo's issues
websearch -p github -m issues --gh-repo owner/repo "breaking change"

# Migration/upgrade paths
websearch -m reason "how to migrate from X v1 to v2"

# Check compatibility
websearch -m reason "is package-A compatible with package-B version X"

# Find changelogs and breaking changes
websearch -p github -m code --gh-filename CHANGELOG "package-name breaking"
```

## Guidelines

- `-p github -m issues` for real reports of dependency conflicts
- `--gh-repo` to search within a specific project's issues
- `-m reason` for migration path analysis
- `--gh-state open` for unresolved, `--gh-state closed` for solved
- Include version numbers for specificity
