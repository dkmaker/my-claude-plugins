#!/bin/bash
# Knowledge plugin SessionStart hook
# Injects research guidance into Claude's context

# Build the additional context message
read -r -d '' CONTEXT << 'EOF'
# Knowledge Plugin Active

When the user asks you to research a topic, use the **knowledge:research** skill for comprehensive research workflows.

## When to Use the Research Skill

- User asks to "research X"
- User wants to investigate or explore a topic
- User needs information gathered from multiple sources
- User asks for a literature review or state-of-the-art summary

## Quick Research (without skill)

For simple factual questions, use web search directly. Only invoke the research skill for:
- Multi-faceted topics requiring structured exploration
- Topics needing source synthesis and citation
- Research that benefits from a systematic approach
EOF

# Output valid JSON for the hook
cat << JSONEOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $(echo "$CONTEXT" | jq -Rs .)
  },
  "systemMessage": "Knowledge plugin loaded"
}
JSONEOF
