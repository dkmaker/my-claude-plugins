#!/bin/bash

# Transcript Helper - Provides transcript operations and context
# Usage:
#   transcript-helper.sh context          - Show current context (env vars, project info)
#   transcript-helper.sh list             - List all transcripts in project
#   transcript-helper.sh create [id]      - Create HTML report for session

set -euo pipefail

# Get script directory for accessing other scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Environment variables (set by SessionStart hook)
CURRENT_SESSION="${CLAUDE_SESSION_ID:-}"
CURRENT_TRANSCRIPT="${CLAUDE_ACTIVE_TRANSCRIPT:-}"
PROJECT_ROOT="${CLAUDE_PROJECT_ROOT:-$(pwd)}"

# Determine project-specific transcript directory
get_project_transcript_dir() {
    # Claude Code stores transcripts in ~/.claude/projects/<hash>/
    # We need to find transcripts for the current project
    if [ -n "$CURRENT_TRANSCRIPT" ]; then
        dirname "$CURRENT_TRANSCRIPT"
    elif [ -n "$CURRENT_SESSION" ]; then
        # Try to find the transcript directory by searching for current session
        local session_file
        session_file=$(find "$HOME/.claude/projects" -name "${CURRENT_SESSION}*.jsonl" 2>/dev/null | head -1)
        if [ -n "$session_file" ]; then
            dirname "$session_file"
        else
            echo "" >&2
            return 1
        fi
    else
        echo "" >&2
        return 1
    fi
}

# Command: context
# Output: JSON with current session info and environment
cmd_context() {
    local transcript_dir
    transcript_dir=$(get_project_transcript_dir || echo "")

    cat <<EOF
{
  "current_session": {
    "session_id": "${CURRENT_SESSION}",
    "short_id": "${CURRENT_SESSION:0:8}",
    "transcript_path": "${CURRENT_TRANSCRIPT}",
    "transcript_exists": $([ -f "$CURRENT_TRANSCRIPT" ] && echo "true" || echo "false")
  },
  "project": {
    "root": "${PROJECT_ROOT}",
    "transcript_dir": "${transcript_dir}"
  },
  "output": {
    "transcripts_folder": "${PROJECT_ROOT}/.transcripts",
    "gitignore": "${PROJECT_ROOT}/.gitignore"
  }
}
EOF
}

# Command: list
# Output: JSON array of all transcripts in project
cmd_list() {
    local transcript_dir
    transcript_dir=$(get_project_transcript_dir || echo "")

    if [ -z "$transcript_dir" ] || [ ! -d "$transcript_dir" ]; then
        echo "[]"
        return 0
    fi

    # Find all .jsonl files in transcript directory
    local transcripts=()
    while IFS= read -r -d '' file; do
        transcripts+=("$file")
    done < <(find "$transcript_dir" -maxdepth 1 -name "*.jsonl" -type f -print0 2>/dev/null)

    if [ ${#transcripts[@]} -eq 0 ]; then
        echo "[]"
        return 0
    fi

    # Build JSON array with transcript metadata
    echo "["
    local first=true
    for transcript in "${transcripts[@]}"; do
        [ "$first" = false ] && echo ","
        first=false

        # Extract metadata from transcript
        local session_id=$(basename "$transcript" .jsonl)
        local short_id="${session_id:0:8}"
        local started_at=$(jq -r 'select(.timestamp != null) | .timestamp' "$transcript" 2>/dev/null | head -n1)
        local branch=$(jq -r 'select(.gitBranch != null) | .gitBranch' "$transcript" 2>/dev/null | head -n1)
        local msg_count=$(jq -s '[.[] | select(.type == "user" or .type == "assistant")] | length' "$transcript" 2>/dev/null)

        cat <<EOF
  {
    "session_id": "$session_id",
    "short_id": "$short_id",
    "file_path": "$transcript",
    "started_at": "${started_at:-unknown}",
    "branch": "${branch:-unknown}",
    "message_count": ${msg_count:-0}
  }
EOF
    done
    echo ""
    echo "]"
}

# Command: create [session-id]
# Create HTML report for specified session (or current if not specified)
cmd_create() {
    local target_session="${1:-$CURRENT_SESSION}"
    local target_short="${target_session:0:8}"

    if [ -z "$target_session" ]; then
        echo "Error: No session ID specified and CLAUDE_SESSION_ID is not set" >&2
        exit 1
    fi

    # Find transcript file
    local transcript_file=""
    local transcript_dir
    transcript_dir=$(get_project_transcript_dir || echo "")

    if [ -z "$transcript_dir" ]; then
        echo "Error: Cannot determine transcript directory" >&2
        exit 1
    fi

    # Try to find transcript by session ID prefix
    while IFS= read -r -d '' file; do
        local basename=$(basename "$file" .jsonl)
        if [[ "$basename" == "$target_session"* ]] || [[ "$basename" == "$target_short"* ]]; then
            transcript_file="$file"
            break
        fi
    done < <(find "$transcript_dir" -maxdepth 1 -name "*.jsonl" -type f -print0 2>/dev/null)

    if [ -z "$transcript_file" ] || [ ! -f "$transcript_file" ]; then
        echo "Error: Transcript not found for session: $target_short" >&2
        exit 1
    fi

    # Ensure output directory exists
    local output_dir="${PROJECT_ROOT}/.transcripts"
    mkdir -p "$output_dir"

    # Ensure .gitignore includes .transcripts/
    local gitignore="${PROJECT_ROOT}/.gitignore"
    if [ -f "$gitignore" ]; then
        if ! grep -q "^\.transcripts/" "$gitignore" 2>/dev/null; then
            echo ".transcripts/" >> "$gitignore"
        fi
    else
        echo ".transcripts/" > "$gitignore"
    fi

    # Get actual session ID from transcript filename
    local actual_session=$(basename "$transcript_file" .jsonl)
    local output_file="${output_dir}/${actual_session}.html"

    # Generate HTML report using render script
    if ! "$SCRIPT_DIR/render-html-js.sh" "$transcript_file" > "$output_file"; then
        echo "Error: Failed to generate HTML report" >&2
        exit 1
    fi

    # Output success JSON
    cat <<EOF
{
  "success": true,
  "session_id": "$actual_session",
  "short_id": "${actual_session:0:8}",
  "transcript_file": "$transcript_file",
  "output_file": "$output_file",
  "relative_path": ".transcripts/${actual_session}.html"
}
EOF
}

# Main command dispatcher
main() {
    local command="${1:-}"

    case "$command" in
        context)
            cmd_context
            ;;
        list)
            cmd_list
            ;;
        create)
            shift
            cmd_create "$@"
            ;;
        *)
            cat >&2 <<EOF
Usage: transcript-helper.sh <command> [args]

Commands:
  context           Show current session and project context
  list              List all transcripts in current project
  create [id]       Create HTML report (current session if no ID)

Examples:
  transcript-helper.sh context
  transcript-helper.sh list
  transcript-helper.sh create
  transcript-helper.sh create 97f85a57
EOF
            exit 1
            ;;
    esac
}

main "$@"
