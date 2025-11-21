---
description: List all available transcripts in the current project
allowed-tools: Bash(transcript-helper.sh:*)
---

# List Transcripts

Use the transcript helper script to list all available transcripts for this project:

!`transcript-helper.sh list`

Analyze the output and present it to the user in a clear, formatted table showing:
- Session ID (short form)
- Date/Time
- Git branch
- Message count
- File path (relative to project root)

If there are no transcripts, inform the user that no transcript sessions were found for this project.
