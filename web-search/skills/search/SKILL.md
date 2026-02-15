---
name: search
description: Search the web using Perplexity AI. Use when the user wants to search, research, ask questions, or reason about topics. Supports ask, search, reason, and research modes with automatic time span detection. Can store valuable results for future reference. The search runs in a resumable subagent.
argument-hint: [ask|search|reason|research] <query>
disable-model-invocation: true
---

# Web Search

Delegate this search to the **web-search** subagent using the Task tool. The subagent is resumable — if the user later wants to save or revisit a result, resume the same agent.

## How to invoke

Use the Task tool with `subagent_type` set to the `web-search` custom agent:

```
Task tool:
  subagent_type: "web-search"
  description: "Web search: <brief topic>"
  prompt: "<the full user query including any mode prefix>"
```

Pass the user's entire input (including any mode like `ask`, `search`, `reason`, `research`) as the prompt. The subagent handles mode detection, time span enrichment, formatting, and storage prompts.

## Resuming

The subagent always asks the user to choose: **Expand** (follow-up question), **Save** (store to archive), or **Done**. If the user picks Expand or Save after the subagent has returned, resume it:

```
Task tool:
  subagent_type: "web-search"
  resume: "<agent-id>"
  prompt: "<what the user wants — e.g. 'Save the result' or 'Expand on X'>"
```

## After the subagent returns

Return the subagent's response directly to the user. Do not reformat, summarize, or wrap it — it is already formatted.
