#!/bin/bash
# block-builtin-websearch.sh
# Blocks the built-in WebSearch tool and web-search Task subagent.
# Instructs Claude to use the websearch:websearch skill instead.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

REASON="BLOCKED: Do not use the built-in ${TOOL_NAME} tool for web searches. You MUST use the Skill tool with skill: \"websearch:websearch\" instead."

if [ "$TOOL_NAME" = "WebSearch" ]; then
  jq -n --arg reason "$REASON" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
fi

if [ "$TOOL_NAME" = "Task" ]; then
  SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty')
  if [ "$SUBAGENT_TYPE" = "web-search" ]; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "BLOCKED: Do not use the Task tool with subagent_type web-search. You MUST use the Skill tool with skill: \"websearch:websearch\" instead."
      }
    }'
    exit 0
  fi
fi

exit 0
