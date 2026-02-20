#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
INSTALL_PATH="$INSTALL_DIR/websearch"
LAST_CHECK_FILE="$HOME/.claude/.websearch-last-update-check"
CHECK_INTERVAL=86400  # 24 hours
REPO="dkmaker/websearch-cli"

# --- Auto-update logic (runs at most once every 24 hours) ---

should_check_update() {
  [ ! -f "$LAST_CHECK_FILE" ] && return 0
  local last now elapsed
  last=$(cat "$LAST_CHECK_FILE" 2>/dev/null || echo 0)
  now=$(date +%s)
  elapsed=$((now - last))
  [ "$elapsed" -ge "$CHECK_INTERVAL" ]
}

install_or_update() {
  # Determine platform
  local os arch
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  case "$arch" in
    x86_64)  arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) return 1 ;;
  esac

  # Get latest release tag
  local latest_tag
  latest_tag=$(gh release view --repo "$REPO" --json tagName -q '.tagName' 2>/dev/null) || return 1
  local latest_version="${latest_tag#v}"

  # Check if current version matches
  if [ -x "$INSTALL_PATH" ]; then
    local current_version
    current_version=$("$INSTALL_PATH" --version 2>/dev/null | grep -oP '[\d.]+' | head -1 || echo "")
    if [ "$current_version" = "$latest_version" ]; then
      date +%s > "$LAST_CHECK_FILE"
      return 0
    fi
  fi

  # Download and install
  local asset_pattern="websearch-cli_${latest_version}_${os}_${arch}.tar.gz"
  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap "rm -rf '$tmp_dir'" EXIT

  gh release download "$latest_tag" --repo "$REPO" --pattern "$asset_pattern" --dir "$tmp_dir" 2>/dev/null || return 1
  tar -xzf "$tmp_dir/$asset_pattern" -C "$tmp_dir" 2>/dev/null || return 1

  mkdir -p "$INSTALL_DIR"
  mv "$tmp_dir/websearch" "$INSTALL_PATH"
  chmod +x "$INSTALL_PATH"
  date +%s > "$LAST_CHECK_FILE"

  trap - EXIT
  rm -rf "$tmp_dir"
  return 0
}

UPDATE_MSG=""
if should_check_update; then
  if install_or_update 2>/dev/null; then
    UPDATE_MSG=" (auto-updated)"
  fi
fi

# --- Detect binary ---

WEBSEARCH_BIN=""
if [ -x "$INSTALL_PATH" ]; then
  WEBSEARCH_BIN="$INSTALL_PATH"
elif command -v websearch &>/dev/null; then
  WEBSEARCH_BIN="websearch"
elif [ -x "$HOME/code/dkmaker/websearch-cli/websearch" ]; then
  WEBSEARCH_BIN="$HOME/code/dkmaker/websearch-cli/websearch"
fi

# --- Output hook JSON ---

if [ -n "$WEBSEARCH_BIN" ]; then
  HELP=$("$WEBSEARCH_BIN" 2>&1 | head -8)
  STATUS="websearch CLI ready${UPDATE_MSG}"
  CONTEXT="# Websearch CLI Available

The \`websearch\` CLI is ready.
Use /websearch for web search and developer research.

${HELP}"
else
  STATUS="WARNING: websearch CLI not found"
  CONTEXT="# Websearch CLI Not Found

The websearch CLI could not be installed or found.
Check that \`gh\` CLI is available and you have access to ${REPO}.
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
