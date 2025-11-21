---
description: Create an HTML report for a transcript session
argument-hint: [session-id]
allowed-tools: Bash(get-transcript-context.sh:*), Bash(transcript-helper.sh:*)
---

# Create Transcript Report

Create a beautiful HTML report for a session transcript.

**Arguments:** `$ARGUMENTS`

## Instructions

1. **First, get context to understand the current state:**
   - Run: !`get-transcript-context.sh`
   - This shows current session ID, available transcripts, and project status

2. **Determine target session:**
   - If `$ARGUMENTS` is empty or whitespace, use the current session from context
   - If `$ARGUMENTS` provided, use it as the session ID (can use short form)

3. **Generate the HTML report:**
   - Run: !`transcript-helper.sh create <session-id>`
   - The helper automatically:
     - Creates `.transcripts/` folder if needed
     - Updates `.gitignore` if needed
     - Generates HTML using render scripts
     - Returns JSON with output file path

4. **Report success:**
   - Parse the JSON output from transcript-helper.sh
   - Show the user the output file path
   - Mention they can open it in a browser
   - Remind them about features:
     - Press `E` to toggle all tools open/closed
     - Expandable tool details
     - Smart truncation for long messages
     - Dark theme optimized for reading

If any errors occur, explain what went wrong based on the error message.
