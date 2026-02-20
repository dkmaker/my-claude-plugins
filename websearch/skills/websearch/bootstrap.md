# Project Bootstrapping

## Commands

```bash
# Find GitHub project templates and starters
websearch -p github "template starter language/framework"

# Filter by language and quality
websearch -p github --gh-language go --gh-stars '>100' "project template"

# Find scaffolding tools
websearch -p github --gh-topic template "framework-name starter"

# Setup/configuration guides
websearch -m reason "how to set up X from scratch with Y"

# Official getting-started docs
websearch -p nodejs "create-react-app alternative"
websearch -p python "python project setup pyproject.toml"
```

## Guidelines

- `-p github` with `--gh-stars` and `--gh-language` for quality templates
- `-m reason` for "how to set up X" step-by-step guidance
- `--gh-topic template` or `--gh-topic starter` for template repos
- `--gh-pushed` to filter for recently maintained templates
- For working config/setup examples, also see [examples.md](examples.md)
