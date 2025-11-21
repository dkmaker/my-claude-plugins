---
description: Create an HTML report for a transcript session
argument-hint: [session-id]
allowed-tools: Bash(transcript-helper.sh:*), Bash(mkdir:*), Bash(grep:*), Bash(echo:*), Write
---

# Create Transcript Report

Create a beautiful HTML report for a session transcript.

**Arguments:** `$ARGUMENTS`

## Instructions

Use the transcript helper to create an HTML report:

1. **Get context and validate session:**
   - Run: !`transcript-helper.sh context`
   - This provides current session ID, project root, and validates arguments

2. **Determine target session:**
   - If `$ARGUMENTS` is empty or whitespace, use current session (from `CLAUDE_SESSION_ID`)
   - If `$ARGUMENTS` provided, use it as the session ID (first 8 characters)
   - Validate the session exists using the helper output

3. **Create output directory:**
   - Ensure `.transcripts/` folder exists in project root
   - Create it if missing: `mkdir -p .transcripts`

4. **Update .gitignore:**
   - Check if `.gitignore` contains `.transcripts/`
   - If not, add it: `echo ".transcripts/" >> .gitignore`

5. **Generate HTML report:**
   - Run: !`transcript-helper.sh create <session-id>`
   - The helper will generate the HTML and save it to `.transcripts/<session-id>.html`

6. **Report success:**
   - Show the user the output file path
   - Mention they can open it in a browser
   - Remind them about keyboard shortcuts (E to toggle tools)

If any errors occur, explain what went wrong and suggest solutions.
