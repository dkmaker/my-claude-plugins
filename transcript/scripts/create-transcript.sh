#!/bin/bash

# Create Transcript Report
# Creates an HTML report for the current Claude Code session
# Outputs markdown describing what happened (success or errors)

# Environment variables set by SessionStart hook
CURRENT_SESSION="${CLAUDE_SESSION_ID:-}"
CURRENT_TRANSCRIPT="${CLAUDE_ACTIVE_TRANSCRIPT:-}"
PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"

# Get script directory for accessing other scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Derived paths
OUTPUT_DIR="${PROJECT_ROOT}/.transcripts"
GITIGNORE_FILE="${PROJECT_ROOT}/.gitignore"

# Validation: Check if we have an active transcript
if [ -z "$CURRENT_TRANSCRIPT" ]; then
    cat <<'EOF'
❌ **Cannot Create Report**

**Problem:** No active transcript session

**Solution:** Make sure you're running this from within an active Claude Code session
EOF
    exit 0
fi

if [ ! -f "$CURRENT_TRANSCRIPT" ]; then
    cat <<'EOF'
❌ **Cannot Create Report**

**Problem:** Transcript file not found

**Solution:** The session transcript may not have been created yet. Try running a few commands first.
EOF
    exit 0
fi

# Check if transcript has any messages
msg_count=$(jq -s '[.[] | select(.type == "user" or .type == "assistant")] | length' "$CURRENT_TRANSCRIPT" 2>/dev/null || echo "0")

if [ "$msg_count" -eq 0 ]; then
    cat <<'EOF'
❌ **Cannot Create Report**

**Problem:** This session has no messages yet

**Solution:** Have a conversation with Claude first, then create the transcript
EOF
    exit 0
fi

# Create output directory
mkdir -p "$OUTPUT_DIR" 2>/dev/null

# Update .gitignore
gitignore_updated=false
if [ -f "$GITIGNORE_FILE" ]; then
    if ! grep -q "^\.transcripts/" "$GITIGNORE_FILE" 2>/dev/null; then
        echo ".transcripts/" >> "$GITIGNORE_FILE"
        gitignore_updated=true
    fi
else
    echo ".transcripts/" > "$GITIGNORE_FILE"
    gitignore_updated=true
fi

# Generate filename
session_short="${CURRENT_SESSION:0:8}"
project_name=$(basename "$PROJECT_ROOT")
timestamp=$(date +%Y%m%d-%H%M%S)
friendly_filename="transcript-${session_short}-${project_name}-${timestamp}.html"
output_file="${OUTPUT_DIR}/${friendly_filename}"

# Generate HTML report using render script
if ! "$SCRIPT_DIR/render-html-js.sh" "$CURRENT_TRANSCRIPT" > "$output_file" 2>/dev/null; then
    cat <<'EOF'
❌ **Failed to Generate Report**

**Problem:** HTML rendering failed

**Solution:** Check that the transcript file is not corrupted and try again
EOF
    exit 0
fi

# Get file size
file_size=$(du -h "$output_file" | cut -f1)

# Success output in markdown
cat <<EOF
✅ **Report Created Successfully**

Your conversation has been saved to an HTML file you can open in any browser.

### File Location

**Path:** \`.transcripts/${friendly_filename}\`
**Size:** ${file_size}

### How to View

**macOS:**
\`\`\`bash
open .transcripts/${friendly_filename}
\`\`\`

**Linux/WSL:**
\`\`\`bash
xdg-open .transcripts/${friendly_filename}
\`\`\`

**Or** just double-click the file in your file manager.

### What's Inside

- 💬 Complete conversation (${msg_count} messages)
- 🛠️ All tool executions with details
- 📊 Statistics and performance metrics
- 🎨 Interactive UI with expand/collapse
- Press \`E\` key to toggle all tools

### Notes

EOF

if [ "$gitignore_updated" = true ]; then
    echo "- ✅ Added \`.transcripts/\` to .gitignore"
fi

echo "- 📁 Report is self-contained (works offline)"
echo ""
echo "**Ready to view or share!**"
