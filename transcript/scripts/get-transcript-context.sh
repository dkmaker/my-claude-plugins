#!/bin/bash

# Get Transcript Context - Provides comprehensive context for transcript operations
# This script outputs all relevant information about the current session,
# available transcripts, and project configuration.

set -euo pipefail

# Environment variables set by the transcript plugin SessionStart hook
CURRENT_SESSION="${CLAUDE_SESSION_ID:-}"
CURRENT_TRANSCRIPT="${CLAUDE_ACTIVE_TRANSCRIPT:-}"
PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"

# Derived paths
TRANSCRIPTS_OUTPUT_DIR="${PROJECT_ROOT}/.transcripts"
GITIGNORE_FILE="${PROJECT_ROOT}/.gitignore"

echo "=== Transcript Context ==="
echo ""

# 1. Current Session Information
echo "Current Session:"
if [ -n "$CURRENT_SESSION" ]; then
    echo "  Session ID: $CURRENT_SESSION"
    echo "  Short ID: ${CURRENT_SESSION:0:8}"
else
    echo "  ✗ Session ID not set"
fi

if [ -n "$CURRENT_TRANSCRIPT" ]; then
    echo "  Transcript: $CURRENT_TRANSCRIPT"
    if [ -f "$CURRENT_TRANSCRIPT" ]; then
        size=$(du -h "$CURRENT_TRANSCRIPT" | cut -f1)
        lines=$(wc -l < "$CURRENT_TRANSCRIPT")
        echo "  ✓ Transcript file exists (${size}, ${lines} lines)"
    else
        echo "  ✗ Transcript file not found"
    fi
else
    echo "  ✗ Transcript path not set"
fi
echo ""

# 2. Project Information
echo "Project:"
echo "  Root: $PROJECT_ROOT"
echo "  Output folder: $TRANSCRIPTS_OUTPUT_DIR"

if [ -d "$TRANSCRIPTS_OUTPUT_DIR" ]; then
    count=$(find "$TRANSCRIPTS_OUTPUT_DIR" -maxdepth 1 -name "*.html" -type f 2>/dev/null | wc -l)
    echo "  ✓ .transcripts/ folder exists (${count} HTML files)"
else
    echo "  ○ .transcripts/ folder does not exist (will be created on first report)"
fi
echo ""

# 3. .gitignore Status
echo ".gitignore Status:"
if [ -f "$GITIGNORE_FILE" ]; then
    if grep -q "^\.transcripts/" "$GITIGNORE_FILE" 2>/dev/null; then
        echo "  ✓ .transcripts/ is in .gitignore"
    else
        echo "  ○ .transcripts/ is NOT in .gitignore (will be added on first report)"
    fi
else
    echo "  ○ .gitignore does not exist (will be created on first report)"
fi
echo ""

# 4. Available Transcripts in Session Folder
echo "Available Transcripts:"

if [ -n "$CURRENT_TRANSCRIPT" ]; then
    TRANSCRIPT_DIR=$(dirname "$CURRENT_TRANSCRIPT")

    if [ -d "$TRANSCRIPT_DIR" ]; then
        transcripts=()
        while IFS= read -r -d '' file; do
            transcripts+=("$file")
        done < <(find "$TRANSCRIPT_DIR" -maxdepth 1 -name "*.jsonl" -type f -print0 2>/dev/null | sort -z)

        if [ ${#transcripts[@]} -gt 0 ]; then
            echo "  Found ${#transcripts[@]} transcript(s) in: $TRANSCRIPT_DIR"
            echo ""
            echo "  ID (short)    Date/Time            Age          Branch       Messages"
            echo "  ────────────  ───────────────────  ───────────  ───────────  ────────"

            # Limit to last 10 transcripts
            start_index=$((${#transcripts[@]} - 10))
            if [ $start_index -lt 0 ]; then
                start_index=0
            fi

            for i in $(seq $start_index $((${#transcripts[@]} - 1))); do
                transcript="${transcripts[$i]}"
                session_id=$(basename "$transcript" .jsonl)
                short_id="${session_id:0:12}"

                # Extract metadata
                started_at=$(jq -r 'select(.timestamp != null) | .timestamp' "$transcript" 2>/dev/null | head -n1)
                branch=$(jq -r 'select(.gitBranch != null) | .gitBranch' "$transcript" 2>/dev/null | head -n1)
                msg_count=$(jq -s '[.[] | select(.type == "user" or .type == "assistant")] | length' "$transcript" 2>/dev/null)

                # Format date
                formatted_date="unknown"
                if [ -n "$started_at" ] && [ "$started_at" != "null" ]; then
                    formatted_date=$(date -d "$started_at" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$started_at")
                fi

                # Calculate age based on file modification time
                file_age="unknown"
                if [ -f "$transcript" ]; then
                    file_mtime=$(stat -c %Y "$transcript" 2>/dev/null || stat -f %m "$transcript" 2>/dev/null)
                    current_time=$(date +%s)
                    age_seconds=$((current_time - file_mtime))

                    # Format age in human-readable form
                    if [ $age_seconds -lt 60 ]; then
                        file_age="${age_seconds}s ago"
                    elif [ $age_seconds -lt 3600 ]; then
                        file_age="$((age_seconds / 60))m ago"
                    elif [ $age_seconds -lt 86400 ]; then
                        file_age="$((age_seconds / 3600))h ago"
                    else
                        file_age="$((age_seconds / 86400))d ago"
                    fi
                fi

                # Format branch
                formatted_branch="${branch:-unknown}"
                if [ ${#formatted_branch} -gt 11 ]; then
                    formatted_branch="${formatted_branch:0:8}..."
                fi

                # Mark current session
                marker=""
                if [ "$session_id" = "$CURRENT_SESSION" ]; then
                    marker="→ "
                else
                    marker="  "
                fi

                printf "  ${marker}%-12s  %-19s  %-11s  %-11s  %8s\n" \
                    "$short_id" \
                    "$formatted_date" \
                    "$file_age" \
                    "$formatted_branch" \
                    "${msg_count:-0}"
            done
        else
            echo "  No transcripts found in: $TRANSCRIPT_DIR"
        fi
    else
        echo "  ✗ Transcript directory not found: $TRANSCRIPT_DIR"
    fi
elif [ -n "$CURRENT_SESSION" ]; then
    # Try to find transcript directory by searching for current session
    session_file=$(find "$HOME/.claude/projects" -name "${CURRENT_SESSION}*.jsonl" 2>/dev/null | head -1)
    if [ -n "$session_file" ]; then
        TRANSCRIPT_DIR=$(dirname "$session_file")
        echo "  Found transcript directory: $TRANSCRIPT_DIR"
        echo "  (Re-run to see full transcript list)"
    else
        echo "  Cannot locate transcript directory"
    fi
else
    echo "  ✗ Cannot determine transcript location (CLAUDE_SESSION_ID not set)"
fi
echo ""

# 5. Generated Reports Status
echo "Generated Reports:"
if [ -d "$TRANSCRIPTS_OUTPUT_DIR" ]; then
    reports=()
    while IFS= read -r -d '' file; do
        reports+=("$file")
    done < <(find "$TRANSCRIPTS_OUTPUT_DIR" -maxdepth 1 -name "*.html" -type f -print0 2>/dev/null | sort -z)

    if [ ${#reports[@]} -gt 0 ]; then
        echo "  Found ${#reports[@]} HTML report(s):"
        echo ""
        echo "  Filename                                        Size     Age          Modified"
        echo "  ──────────────────────────────────────────────  ───────  ───────────  ────────────────────"

        for report in "${reports[@]}"; do
            report_name=$(basename "$report")
            size=$(du -h "$report" | cut -f1)
            modified=$(stat -c %y "$report" 2>/dev/null | cut -d'.' -f1 || echo "unknown")

            # Calculate age
            report_age="unknown"
            if [ -f "$report" ]; then
                file_mtime=$(stat -c %Y "$report" 2>/dev/null || stat -f %m "$report" 2>/dev/null)
                current_time=$(date +%s)
                age_seconds=$((current_time - file_mtime))

                # Format age in human-readable form
                if [ $age_seconds -lt 60 ]; then
                    report_age="${age_seconds}s ago"
                elif [ $age_seconds -lt 3600 ]; then
                    report_age="$((age_seconds / 60))m ago"
                elif [ $age_seconds -lt 86400 ]; then
                    report_age="$((age_seconds / 3600))h ago"
                else
                    report_age="$((age_seconds / 86400))d ago"
                fi
            fi

            printf "  %-46s  %7s  %-11s  %s\n" \
                "$report_name" \
                "$size" \
                "$report_age" \
                "$modified"
        done
    else
        echo "  No HTML reports generated yet"
    fi
else
    echo "  No reports (output folder does not exist)"
fi
echo ""

# 6. Quick Commands Reference
echo "Available Commands:"
echo "  /transcript:help              - Show usage guide"
echo "  /transcript:list              - List all available transcripts"
echo "  /transcript:create            - Create report for current session"
echo "  /transcript:create <id>       - Create report for specific session (use short ID)"
echo ""

# 7. Summary for slash commands
echo "Summary:"
echo "  Current session: ${CURRENT_SESSION:0:8}"
echo "  Output directory: $TRANSCRIPTS_OUTPUT_DIR"
echo "  .gitignore: $([ -f "$GITIGNORE_FILE" ] && grep -q "^\.transcripts/" "$GITIGNORE_FILE" 2>/dev/null && echo "configured" || echo "needs update")"
echo "  Ready to generate reports: $([ -n "$CURRENT_TRANSCRIPT" ] && [ -f "$CURRENT_TRANSCRIPT" ] && echo "YES" || echo "NO")"
echo ""
