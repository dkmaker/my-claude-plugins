---
description: List all available transcripts in the current project
allowed-tools: Bash(get-transcript-context.sh:*)
---

# List Transcripts

Show the user all available session transcripts they can create reports from.

!`get-transcript-context.sh`

Present the information in a user-friendly format. Use this template:

```
# 📝 Your Transcript Sessions

## Current Session
- **Session ID**: `<short_id>` (<full session_id>)
- **Status**: <transcript exists status and size>

## Available Sessions

You have **<total count>** conversation sessions in this project. Here are the most recent:

<Display the transcript table from context output>

## Generated Reports

<If reports exist>
You've already created **<count>** HTML report(s):

<Display the reports table from context output>

<If no reports>
No reports generated yet. Run `/transcript:create` to create one!

## Quick Actions

**Create a report for your current session:**
```
/transcript:create
```

**Create a report for a past session:**
```
/transcript:create <session-id>
```
Use the session ID from the list above (just the first 8 characters).

**Learn more:**
```
/transcript:help
```
```

Focus on helping the user understand:
- What sessions they have available
- Which is their current session
- How to create reports from any session
- Where existing reports are saved
