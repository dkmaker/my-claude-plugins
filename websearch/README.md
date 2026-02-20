# Websearch Plugin

Web search and developer research plugin for Claude Code, powered by the [`websearch` CLI](https://github.com/dkmaker/websearch-cli).

## Usage

Invoke with `/websearch <query>` or let Claude auto-detect when web search is needed.

Claude automatically determines the research area and loads the appropriate strategy:

- **Debugging** — errors, crashes, stack traces, performance issues
- **Documentation** — library/API docs, usage examples, configuration
- **Patterns** — best practices, design patterns, architecture decisions
- **Bootstrapping** — project templates, starter configs, setup guides
- **Dependencies** — version conflicts, migrations, breaking changes
- **Exploration** — GitHub repos, code search, implementations
- **General** — news, facts, any other web search

## Requirements

- `websearch` CLI binary (on PATH or at `~/code/dkmaker/websearch-cli/websearch`)
- Provider API keys configured (see websearch CLI docs)

## Search Providers

- **Perplexity**: ask, search, reason, research modes
- **Brave**: web search
- **GitHub**: repos, code, issues search
