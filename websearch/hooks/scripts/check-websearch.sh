#!/usr/bin/env bash
set -euo pipefail

WEBSEARCH_BIN=""
if command -v websearch &>/dev/null; then
  WEBSEARCH_BIN="websearch"
elif [ -x "$HOME/code/dkmaker/websearch-cli/websearch" ]; then
  WEBSEARCH_BIN="$HOME/code/dkmaker/websearch-cli/websearch"
fi

if [ -n "$WEBSEARCH_BIN" ]; then
  HELP=$("$WEBSEARCH_BIN" 2>&1 | head -8)
  STATUS="websearch CLI ready"
  CONTEXT="# Websearch CLI Available

The \`websearch\` CLI is ready (binary: ${WEBSEARCH_BIN}).
Use /websearch for web search and developer research.

${HELP}"
else
  STATUS="WARNING: websearch CLI not found"
  CONTEXT="# Websearch CLI Not Found

The websearch CLI binary was not found on PATH or at ~/code/dkmaker/websearch-cli/websearch.
The /websearch skill will not work without it."
fi

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $(printf '%s' "$CONTEXT" | jq -Rs .)
  },
  "systemMessage": $(printf '%s' "$STATUS" | jq -Rs .)
}
EOF
