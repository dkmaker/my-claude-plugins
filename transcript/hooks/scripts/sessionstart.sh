#!/bin/bash

# This hook persists transcript path and session ID as environment variables
# and adds the scripts folder to PATH

# Read input JSON
INPUT_JSON=$(cat)

# Set up basic environment
export CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
export CLAUDE_SESSION_ID=$(echo "$INPUT_JSON" | jq -r '.session_id // empty')
export TRANSCRIPT_PATH=$(echo "$INPUT_JSON" | jq -r '.transcript_path // empty')
export PROJECT_ROOT=$(echo "$INPUT_JSON" | jq -r '.cwd // empty')

# Debug logging function - only logs if CLAUDE_HOOK_DEBUG_LOG is set
debug_log() {
    if [ -n "$CLAUDE_HOOK_DEBUG_LOG" ]; then
        echo "$@" >> "$CLAUDE_HOOK_DEBUG_LOG"
    fi
}

debug_log "===== Starting transcript-sessionstart.sh Hook $(date) ====="
debug_log ""
debug_log "CLAUDE-SPECIFIC VARIABLES:"
debug_log "CLAUDE_HOME: ${CLAUDE_HOME:-<not set>}"
debug_log "CLAUDE_PROJECT_DIR: ${CLAUDE_PROJECT_DIR:-<not set>}"
debug_log "CLAUDE_PLUGIN_ROOT: ${CLAUDE_PLUGIN_ROOT:-<not set>}"
debug_log "CLAUDE_SESSION_ID: ${CLAUDE_SESSION_ID:-<not set>}"
debug_log "CLAUDE_ENV_FILE: ${CLAUDE_ENV_FILE:-<not set>}"
debug_log "TRANSCRIPT_PATH: ${TRANSCRIPT_PATH:-<not set>}"

# Create CLAUDE_ENV_FILE if not set (workaround for Claude Code bug with plugin hooks)
if [ -z "$CLAUDE_ENV_FILE" ] && [ -n "$CLAUDE_SESSION_ID" ] && [ -n "$CLAUDE_HOME" ]; then
    export CLAUDE_ENV_FILE="$CLAUDE_HOME/session-env/$CLAUDE_SESSION_ID/hook-0.sh"
    # Create the directory if it doesn't exist
    mkdir -p "$(dirname "$CLAUDE_ENV_FILE")"
    # Create the file if it doesn't exist
    touch "$CLAUDE_ENV_FILE"
    debug_log "✓ Created CLAUDE_ENV_FILE: $CLAUDE_ENV_FILE"
fi

# Shared utility function to update or add environment variables
# Usage: set_env_var "VAR_NAME" "value"
set_env_var() {
    local var_name="$1"
    local var_value="$2"

    # Validate inputs
    if [ -z "$var_name" ]; then
        debug_log "ERROR: Variable name is required"
        return 1
    fi

    # Skip if CLAUDE_ENV_FILE is not set
    if [ -z "$CLAUDE_ENV_FILE" ]; then
        debug_log "WARNING: CLAUDE_ENV_FILE is not set, skipping ${var_name}"
        return 0
    fi

    # Create the directory if it doesn't exist
    local env_dir
    env_dir="$(dirname "$CLAUDE_ENV_FILE")"
    if [ ! -d "$env_dir" ]; then
        mkdir -p "$env_dir" || {
            debug_log "ERROR: Failed to create directory: $env_dir"
            return 1
        }
    fi

    # Create the file if it doesn't exist
    if [ ! -f "$CLAUDE_ENV_FILE" ]; then
        touch "$CLAUDE_ENV_FILE" || {
            debug_log "ERROR: Failed to create file: $CLAUDE_ENV_FILE"
            return 1
        }
    fi

    # Build the export line
    local export_line="export ${var_name}=\"${var_value}\""

    # Check if the variable already exists in the file
    if grep -q "^export ${var_name}=" "$CLAUDE_ENV_FILE"; then
        # Update existing variable using sed
        sed -i "s|^export ${var_name}=.*|${export_line}|" "$CLAUDE_ENV_FILE"
        debug_log "Updated ${var_name} in ${CLAUDE_ENV_FILE}"
    else
        # Append new variable
        echo "$export_line" >> "$CLAUDE_ENV_FILE"
        debug_log "Added ${var_name} to ${CLAUDE_ENV_FILE}"
    fi

    return 0
}

# Add the scripts folder to PATH and persist environment variables
if [ -n "$CLAUDE_ENV_FILE" ]; then
    debug_log ""
    debug_log "Setting environment variables in CLAUDE_ENV_FILE..."

    # Set PATH with the scripts folder
    set_env_var "PATH" "${CLAUDE_PLUGIN_ROOT}/scripts:\$PATH"

    # Set CLAUDE_SESSION_ID
    set_env_var "CLAUDE_SESSION_ID" "$CLAUDE_SESSION_ID"

    # Set CLAUDE_ACTIVE_TRANSCRIPT (the transcript path)
    if [ -n "$TRANSCRIPT_PATH" ]; then
        set_env_var "CLAUDE_ACTIVE_TRANSCRIPT" "$TRANSCRIPT_PATH"
        debug_log "✓ Set CLAUDE_ACTIVE_TRANSCRIPT: $TRANSCRIPT_PATH"
    fi

    # Set CLAUDE_PROJECT_ROOT
    if [ -n "$PROJECT_ROOT" ]; then
        set_env_var "CLAUDE_PROJECT_ROOT" "$PROJECT_ROOT"
        debug_log "✓ Set CLAUDE_PROJECT_ROOT: $PROJECT_ROOT"
    fi

    debug_log ""
    debug_log "✓ Environment variables updated"
    if [ -n "$CLAUDE_HOOK_DEBUG_LOG" ]; then
        debug_log "CLAUDE_ENV_FILE contents:"
        cat "$CLAUDE_ENV_FILE" >> "$CLAUDE_HOOK_DEBUG_LOG" 2>&1
    fi
else
    debug_log ""
    debug_log "⚠ WARNING: CLAUDE_ENV_FILE is not set!"
fi

debug_log ""
debug_log "Hook execution completed successfully"
debug_log ""

# Output JSON with hookSpecificOutput format (silent with helpful context)
jq -n \
  '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: "# Transcript Plugin Available\n\nIf the user is confused, needs to review the conversation, debug issues, or wants to see the complete chat history with all tool details, suggest using `/transcript:create` to generate an HTML report. This is especially helpful for complex sessions with many tool calls or when troubleshooting problems."
    },
    systemMessage: ""
  }'

debug_log "JSON output generated successfully"

exit 0
