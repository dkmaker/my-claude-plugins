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

# ANSI color codes for better readability
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BOLD}=== Transcript Context ===${NC}"
echo ""

# 1. Current Session Information
echo -e "${BOLD}Current Session:${NC}"
if [ -n "$CURRENT_SESSION" ]; then
    echo "  Session ID: $CURRENT_SESSION"
    echo "  Short ID: ${CURRENT_SESSION:0:8}"
else
    echo -e "  ${RED}✗ Session ID not set${NC}"
fi

if [ -n "$CURRENT_TRANSCRIPT" ]; then
    echo "  Transcript: $CURRENT_TRANSCRIPT"
    if [ -f "$CURRENT_TRANSCRIPT" ]; then
        size=$(du -h "$CURRENT_TRANSCRIPT" | cut -f1)
        lines=$(wc -l < "$CURRENT_TRANSCRIPT")
        echo -e "  ${GREEN}✓ Transcript file exists${NC} (${size}, ${lines} lines)"
    else
        echo -e "  ${RED}✗ Transcript file not found${NC}"
    fi
else
    echo -e "  ${RED}✗ Transcript path not set${NC}"
fi
echo ""

# 2. Project Information
echo -e "${BOLD}Project:${NC}"
echo "  Root: $PROJECT_ROOT"
echo "  Output folder: $TRANSCRIPTS_OUTPUT_DIR"

if [ -d "$TRANSCRIPTS_OUTPUT_DIR" ]; then
    count=$(find "$TRANSCRIPTS_OUTPUT_DIR" -maxdepth 1 -name "*.html" -type f 2>/dev/null | wc -l)
    echo -e "  ${GREEN}✓ .transcripts/ folder exists${NC} (${count} HTML files)"
else
    echo -e "  ${YELLOW}○ .transcripts/ folder does not exist${NC} (will be created on first report)"
fi
echo ""

# 3. .gitignore Status
echo -e "${BOLD}.gitignore Status:${NC}"
if [ -f "$GITIGNORE_FILE" ]; then
    if grep -q "^\.transcripts/" "$GITIGNORE_FILE" 2>/dev/null; then
        echo -e "  ${GREEN}✓ .transcripts/ is in .gitignore${NC}"
    else
        echo -e "  ${YELLOW}○ .transcripts/ is NOT in .gitignore${NC} (will be added on first report)"
    fi
else
    echo -e "  ${YELLOW}○ .gitignore does not exist${NC} (will be created on first report)"
fi
echo ""

# 4. Available Transcripts in Session Folder
echo -e "${BOLD}Available Transcripts:${NC}"

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
            echo "  ${BOLD}ID (short)    Date/Time            Branch       Messages  File${NC}"
            echo "  ────────────  ───────────────────  ───────────  ────────  ────────────────────────────────"

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

                # Format branch
                formatted_branch="${branch:-unknown}"
                if [ ${#formatted_branch} -gt 11 ]; then
                    formatted_branch="${formatted_branch:0:8}..."
                fi

                # Mark current session
                marker=""
                if [ "$session_id" = "$CURRENT_SESSION" ]; then
                    marker="${GREEN}→${NC} "
                else
                    marker="  "
                fi

                printf "  ${marker}%-12s  %-19s  %-11s  %8s  %s\n" \
                    "$short_id" \
                    "$formatted_date" \
                    "$formatted_branch" \
                    "${msg_count:-0}" \
                    "$(basename "$transcript")"
            done
        else
            echo -e "  ${YELLOW}No transcripts found in: $TRANSCRIPT_DIR${NC}"
        fi
    else
        echo -e "  ${RED}✗ Transcript directory not found: $TRANSCRIPT_DIR${NC}"
    fi
elif [ -n "$CURRENT_SESSION" ]; then
    # Try to find transcript directory by searching for current session
    session_file=$(find "$HOME/.claude/projects" -name "${CURRENT_SESSION}*.jsonl" 2>/dev/null | head -1)
    if [ -n "$session_file" ]; then
        TRANSCRIPT_DIR=$(dirname "$session_file")
        echo "  Found transcript directory: $TRANSCRIPT_DIR"
        echo "  (Re-run to see full transcript list)"
    else
        echo -e "  ${YELLOW}Cannot locate transcript directory${NC}"
    fi
else
    echo -e "  ${RED}✗ Cannot determine transcript location (CLAUDE_SESSION_ID not set)${NC}"
fi
echo ""

# 5. Generated Reports Status
echo -e "${BOLD}Generated Reports:${NC}"
if [ -d "$TRANSCRIPTS_OUTPUT_DIR" ]; then
    reports=()
    while IFS= read -r -d '' file; do
        reports+=("$file")
    done < <(find "$TRANSCRIPTS_OUTPUT_DIR" -maxdepth 1 -name "*.html" -type f -print0 2>/dev/null | sort -z)

    if [ ${#reports[@]} -gt 0 ]; then
        echo "  Found ${#reports[@]} HTML report(s):"
        echo ""
        echo "  ${BOLD}Session ID (short)    Size     Modified              File${NC}"
        echo "  ────────────────────  ───────  ────────────────────  ────────────────────────────────"

        for report in "${reports[@]}"; do
            report_basename=$(basename "$report" .html)
            short_id="${report_basename:0:20}"
            size=$(du -h "$report" | cut -f1)
            modified=$(stat -c %y "$report" 2>/dev/null | cut -d'.' -f1 || echo "unknown")

            printf "  %-20s  %7s  %s  %s\n" \
                "$short_id" \
                "$size" \
                "$modified" \
                "$(basename "$report")"
        done
    else
        echo -e "  ${YELLOW}No HTML reports generated yet${NC}"
    fi
else
    echo -e "  ${YELLOW}No reports (output folder does not exist)${NC}"
fi
echo ""

# 6. Quick Commands Reference
echo -e "${BOLD}Available Commands:${NC}"
echo "  /transcript:help              - Show usage guide"
echo "  /transcript:list              - List all available transcripts"
echo "  /transcript:create            - Create report for current session"
echo "  /transcript:create <id>       - Create report for specific session (use short ID)"
echo ""

# 7. Summary for slash commands
echo -e "${BOLD}Summary:${NC}"
echo "  Current session: ${CURRENT_SESSION:0:8}"
echo "  Output directory: $TRANSCRIPTS_OUTPUT_DIR"
echo "  .gitignore: $([ -f "$GITIGNORE_FILE" ] && grep -q "^\.transcripts/" "$GITIGNORE_FILE" 2>/dev/null && echo "configured" || echo "needs update")"
echo "  Ready to generate reports: $([ -n "$CURRENT_TRANSCRIPT" ] && [ -f "$CURRENT_TRANSCRIPT" ] && echo "YES" || echo "NO")"
echo ""
