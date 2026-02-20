---
name: websearch
description: >
  Web search and developer research. Use for ANY of these:
  searching the web, looking up documentation, debugging errors/crashes/issues,
  researching best practices and design patterns, finding project templates and
  setup guides, resolving dependency conflicts, or exploring GitHub repositories
  and code. Handles both general web queries and development-specific research.
allowed-tools: Bash(websearch *), Bash(~/.local/bin/websearch *), Read
---

# Websearch — Web Search & Developer Research

Search the web and research development topics using the `websearch` CLI.

## Determine the research area

Based on the user's request, identify which area applies:

| Area | When to use | Supporting file |
|------|------------|-----------------|
| Debugging | Error messages, stack traces, crashes, deadlocks, performance issues | [debug.md](debug.md) |
| Documentation | Library/API docs, usage examples, configuration references | [docs.md](docs.md) |
| Patterns | Best practices, design patterns, architecture decisions, conventions | [patterns.md](patterns.md) |
| Bootstrapping | Project templates, starter configs, initial setup, scaffolding | [bootstrap.md](bootstrap.md) |
| Dependencies | Version conflicts, migrations, breaking changes, compatibility | [deps.md](deps.md) |
| Exploration | GitHub repos, code search, finding implementations | [explore.md](explore.md) |
| General | Everything else — news, facts, general questions | [search.md](search.md) |

**Read the matching supporting file** for specific commands and strategies, then execute the search.

## Mode selection — CRITICAL

**Avoid `-m research` unless truly necessary.** It is slow (up to 5 minutes), expensive, and often overkill.

**Preferred approach:** Run multiple focused searches with `-m ask`, `-m search`, or `-m reason` from different angles, then synthesize the results yourself. This is faster, cheaper, and usually produces better answers than a single broad research query.

**When `-m research` IS appropriate:**
- Comprehensive literature reviews or state-of-the-art surveys
- Questions requiring synthesis across many conflicting sources
- Deep technical analysis where surface-level results are insufficient
- The user explicitly needs exhaustive coverage of a complex topic

**When NOT to use `-m research`** (even if user says "research"):
- Regular development questions → use `-m ask` or `-m reason`
- Comparing two approaches → use `-m reason`
- Finding docs or examples → use `-m ask`
- Anything answerable in a few searches → combine multiple `-m ask`/`-m reason` calls

**If you must use `-m research`**, run it in the background with `run_in_background: true` on the Bash tool, since it can take up to 5 minutes. Continue other work while waiting.

## Quick reference

```bash
# The websearch binary (use whichever is available)
websearch "query"

# Key flags
-m <mode>        # ask (default), search, reason, research (AVOID - see above)
-p <profile>     # general (default), github, nodejs, python
--provider <p>   # perplexity (default), brave, github
--include-sources # include citation URLs
--no-cache       # bypass 60m cache
--json           # JSON output
```

## Arguments

$ARGUMENTS
