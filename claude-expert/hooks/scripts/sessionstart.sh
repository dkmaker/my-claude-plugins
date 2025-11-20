#!/bin/bash

# This hook injects context on session startup to instruct Claude Code
# to always use the knowledge skill for Claude Code related questions

# Read input JSON
INPUT_JSON=$(cat)

# Set up basic environment
export CLAUDE_HOME="$HOME/.claude"
export CLAUDE_SESSION_ID=$(echo "$INPUT_JSON" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4)

# Debug logging function - only logs if CLAUDE_HOOK_DEBUG_LOG is set
debug_log() {
    if [ -n "$CLAUDE_HOOK_DEBUG_LOG" ]; then
        echo "$@" >> "$CLAUDE_HOOK_DEBUG_LOG"
    fi
}

debug_log "===== Starting claude-expert-sessionstart.sh Hook $(date) ====="
debug_log ""
debug_log "CLAUDE-SPECIFIC VARIABLES:"
debug_log "CLAUDE_HOME: ${CLAUDE_HOME:-<not set>}"
debug_log "CLAUDE_PROJECT_DIR: ${CLAUDE_PROJECT_DIR:-<not set>}"
debug_log "CLAUDE_PLUGIN_ROOT: ${CLAUDE_PLUGIN_ROOT:-<not set>}"
debug_log "CLAUDE_SESSION_ID: ${CLAUDE_SESSION_ID:-<not set>}"
debug_log "CLAUDE_ENV_FILE: ${CLAUDE_ENV_FILE:-<not set>}"

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

# Add the scripts folder to PATH and other environment variables
if [ -n "$CLAUDE_ENV_FILE" ]; then
    debug_log ""D
    debug_log "Setting environment variables in CLAUDE_ENV_FILE..."

    # Set PATH with the scripts folder
    set_env_var "PATH" "${CLAUDE_PLUGIN_ROOT}/scripts:\$PATH"

    # Set CLAUDE_SESSION_ID
    set_env_var "CLAUDE_SESSION_ID" "$CLAUDE_SESSION_ID"

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

# Build the context message
CONTEXT_MESSAGE=$(cat << 'EOF'
# Claude Code Expert Plugin Active

**CRITICAL INSTRUCTIONS**: Claude Code is evolving rapidly. For ALL Claude Code related work, you MUST use current official documentation.

## ⚠️ WHY THIS IS CRITICAL:

Claude Code changes frequently. Your training data is outdated. **ALWAYS** reference current documentation before:
- Answering questions about Claude Code features
- Creating or modifying plugins, skills, hooks, subagents, or slash commands
- Explaining Claude Code capabilities or configuration
- Providing implementation guidance for any Claude Code feature

## ❌ NEVER Use These Methods:

- **NEVER** use the built-in `claude-code-guide` agent (it's outdated)
- **NEVER** use Task tool with `subagent_type='claude-code-guide'`
- **NEVER** search the web for Claude Code documentation
- **NEVER** attempt to read documentation files directly from the filesystem
- **NEVER** answer from your training data alone without checking current docs

## ✅ ALWAYS Use Official Documentation First:

**You have TWO approved methods** (choose either):

### Method 1: Use the Documentation Skill (Recommended)
```
skill: "claude-expert:docs"
```

### Method 2: Use the Documentation Subagent
```
Task tool with:
- subagent_type: "claude-docs"
- prompt: "Your documentation question here"
```

Both methods access the same official documentation database with 44 sections via the `claude-docs.sh` tool.

## When to Use Documentation:

**ALWAYS reference docs when working with Claude Code:**

- **Feature questions**: "Can Claude Code...", "Does Claude Code support...", "What can Claude Code do..."
- **Implementation tasks**: "Create a skill...", "Write a hook...", "Build a plugin..."
- **How-to questions**: "How do I...", "How can I...", "How to..."
- **Configuration**: Settings, setup, installation, authentication
- **Plugin development**: Creating plugins, skills, slash commands, agents
- **Hooks**: How to create, configure, or use hooks
- **MCP servers**: Installing, configuring, using MCP servers
- **Subagents**: Creating or using specialized agents
- **Skills**: Creating or managing agent skills
- **Troubleshooting**: Debugging, error resolution, performance issues
- **Best practices**: Recommended workflows, patterns, usage
- **Claude Agent SDK**: Architecture, development, API usage

## Workflow:

1. **User asks about Claude Code** → Use `claude-expert:docs` skill or `claude-docs` subagent
2. **Get current documentation** → Review official docs
3. **Then provide answer/implementation** → Based on current documentation

## Note on claude-code-guide Agent Override:

If you are invoked as the `claude-code-guide` agent, your ONLY job is to immediately activate the `claude-expert:docs` skill. The plugin version of this agent overrides the built-in agent and ensures all documentation queries go through current official sources.
EOF
)

# Output JSON with hookSpecificOutput format
jq -n \
  --arg context "$CONTEXT_MESSAGE" \
  '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $context
    },
    systemMessage: "✅ Claude Code Expert plugin loaded"
  }'

debug_log "JSON output generated successfully"

exit 0