---
name: websearch
description: Web search, developer research, and library docs. Use for searching the web, looking up docs, debugging errors, researching patterns, bootstrapping projects, resolving dependencies, exploring GitHub code, or finding code examples.
argument-hint: "[query or topic]"
allowed-tools: Bash(websearch *), Bash(~/.local/bin/websearch *), Read, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, mcp__context7__*
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
| Code Examples | Find working code snippets, config examples, implementation samples | [examples.md](examples.md) |
| Exploration | GitHub repos, finding libraries and implementations | [explore.md](explore.md) |
| General | Everything else — news, facts, general questions | [search.md](search.md) |
| CLI Setup | Install, update, or troubleshoot the websearch CLI | [cli-setup.md](cli-setup.md) |

**Read the matching supporting file** for specific commands and strategies, then execute the search.

## Complexity check — before searching

Before executing searches, assess the request complexity:

**Simple** (just search): Single question, clear scope, one area → search immediately.

**Complex** (offer interview): Any of these signals:
- Multi-faceted topic spanning several areas
- Vague or broad request ("research X", "tell me about Y")
- Architecture/design decisions with many variables
- User explicitly asks for an interview or deep dive
- The topic would benefit from `-m research` mode

When complexity is detected, **offer the user a choice** using AskUserQuestion:

> "This looks like a complex topic. Want me to interview you first to nail down exactly what to search for?"

Options: **Quick search** (proceed immediately) / **Interview first** (refine the scope)

### Interview process (if chosen or requested directly)

When the user confirms interview, immediately create tasks to track the process:

```
TaskCreate: "Interview: scope and context" (activeForm: "Interviewing about scope")
TaskCreate: "Interview: constraints and requirements" (activeForm: "Interviewing about constraints")
TaskCreate: "Interview: priorities" (activeForm: "Interviewing about priorities")
TaskCreate: "Build and approve search plan" (activeForm: "Building search plan")
TaskCreate: "Execute search plan" (activeForm: "Executing searches")
TaskCreate: "Synthesize results" (activeForm: "Synthesizing research results")
```

Mark each task in_progress as you start it, completed when done.

**Level 1 — Scope** (mark task in_progress): What specific aspects matter? What's the context? Use AskUserQuestion with concrete options based on the topic. (e.g., "Which parts of auth are you exploring?" with options: "Session management", "OAuth providers", "Token strategy")

**Level 2 — Constraints** (mark task in_progress): What tech stack, scale, or requirements apply? What have you already tried or ruled out? Use AskUserQuestion. (e.g., "Are you using a specific framework?" with relevant options)

**Level 3 — Priorities** (mark task in_progress, skip if already clear): What matters most — performance, simplicity, security? Any dealbreakers? Use AskUserQuestion.

### Search plan proposal (requires approval)

After the interview, build a **search plan** and **present it for approval** using AskUserQuestion:

List 3-6 specific searches you plan to run, each with:
- The exact websearch command (mode, profile, flags)
- What angle or dimension this search covers
- How it connects to what the user told you

Ask: "Here's my search plan based on our discussion. Should I proceed?"
Options: **Execute plan** / **Adjust plan** (let user provide feedback to refine)

If the user says "Adjust", revise and re-propose. Only execute after approval.

Once approved, create a task per search in the plan, then execute them — marking each in_progress/completed as you go. After all searches complete, synthesize the results.

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

## Context7 — library documentation

This plugin includes the **Context7 MCP server** for version-specific library documentation. Use the Context7 tools (`resolve-library-id` then `query-docs`) when:

- Looking up **specific library/framework API** usage (e.g., "how does Next.js App Router handle layouts")
- The user is working with a **specific version** of a library and needs accurate docs
- You need **code examples from official docs** rather than blog posts or Stack Overflow
- **websearch returns outdated or generic info** about a rapidly evolving library

**Do NOT use Context7 for:**
- General web questions, news, or non-library topics → use websearch
- Architecture decisions or pattern comparisons → use websearch `-m reason`
- Debugging errors → use websearch (GitHub issues, Stack Overflow)
- Finding repos or projects → use websearch `-p github`

**Workflow:** First `resolve-library-id` to find the library ID, then `query-docs` with a specific question. Context7 is slower and more token-expensive than websearch, so only use it when library-specific accuracy matters.

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
