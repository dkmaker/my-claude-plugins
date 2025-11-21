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

   !`get-transcript-context.sh`

   This shows current session ID, available transcripts, and project status.

2. **Determine target session:**
   - If `$ARGUMENTS` is empty or whitespace, use the current session ID from the context output
   - If `$ARGUMENTS` is provided, use it as the session ID (can use short form like "b061b235")

3. **Generate the HTML report:**

   Run the helper with the determined session ID. For example, if the session is "b061b235":

   !`transcript-helper.sh create b061b235`

   The helper automatically:
   - Creates `.transcripts/` folder if needed
   - Updates `.gitignore` if needed
   - Generates HTML using render scripts
   - Returns JSON with output file path

4. **Report success to the user:**

   Present the information in a user-friendly way. Use this template:

   ```
   # ✅ Report Created Successfully!

   Your conversation has been saved to an HTML file you can open in any browser.

   ## File Location

   **Filename:** `<friendly_filename from JSON>`
   **Full path:** `<output_file from JSON>`

   ## How to View

   Open the file in your browser:

   ```bash
   # macOS
   open .transcripts/<friendly_filename>

   # Linux/WSL
   xdg-open .transcripts/<friendly_filename>

   # Or just double-click the file in your file manager
   ```

   ## What's Inside

   Your report includes:
   - The complete conversation with all messages
   - Every tool Claude used and their results
   - Statistics about token usage and performance
   - Interactive elements for easy navigation

   ## Tips for Viewing

   - **Press `E` key** to expand/collapse all tools at once
   - **Click tool cards** to see individual command details
   - **Long messages** are collapsed - click "Show more" to expand them
   - **Self-contained** - works offline, no internet needed

   The report is ready to view or share!
   ```

If any errors occur, explain what went wrong in simple terms and suggest how to fix it.
