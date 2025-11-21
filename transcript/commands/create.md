---
description: Create an HTML report for a transcript session
argument-hint: [session-id]
allowed-tools: Bash(get-transcript-context.sh:*), Bash(transcript-helper.sh:*)
---

# Create Transcript Report

Create a beautiful HTML report for a session transcript.

**Arguments:** `$ARGUMENTS`
- If empty: Creates report for the current session
- If provided: Session ID (short form like "b061b235" or full UUID)

## Instructions

1. **First, get context to understand the current state:**

   !`get-transcript-context.sh`

   This shows current session ID, available transcripts, and project status.

2. **Determine which session to use:**
   - If the user provided no arguments, use the current session ID (short form) from the context output
   - If the user provided a session ID, use exactly what they provided

3. **Verify .gitignore protection (CRITICAL - transcripts may contain sensitive data):**

   Check the .gitignore status from step 1 context output:
   - If it shows "✓ .transcripts/ is in .gitignore" → Safe to proceed
   - If it shows anything else → Warn the user that .gitignore needs to be configured first

   The helper will add .gitignore automatically, but inform the user this is happening.

4. **Generate the HTML report:**

   Construct and run the helper command with the actual session ID from step 2.

   Build the command: `transcript-helper.sh create <session-id-from-step-2>`

   Then execute it with the bash invocation prefix to get the JSON response.

   Important: Use the ACTUAL session ID determined in step 2, not a placeholder or example.

   Parse the JSON response for the output file information.

5. **Report success to the user:**

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
