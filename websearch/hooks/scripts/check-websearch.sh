#!/usr/bin/env bash
set -euo pipefail

LAST_CHECK_FILE="$HOME/.claude/.websearch-last-update-check"
CHECK_INTERVAL=86400  # 24 hours
REPO="dkmaker/websearch-cli"

# --- Platform detection ---

detect_platform() {
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)

  case "$ARCH" in
    x86_64)        ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) return 1 ;;
  esac

  # Normalize OS and set platform-specific values
  case "$OS" in
    linux)
      INSTALL_DIR="$HOME/.local/bin"
      BIN_NAME="websearch"
      ARCHIVE_EXT="tar.gz"
      ;;
    darwin)
      INSTALL_DIR="$HOME/.local/bin"
      BIN_NAME="websearch"
      ARCHIVE_EXT="tar.gz"
      ;;
    mingw*|msys*|cygwin*)
      OS="windows"
      INSTALL_DIR="$HOME/.local/bin"
      BIN_NAME="websearch.exe"
      ARCHIVE_EXT="zip"
      ;;
    *)
      return 1
      ;;
  esac

  INSTALL_PATH="$INSTALL_DIR/$BIN_NAME"
}

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
  # Get latest release tag
  local latest_tag
  latest_tag=$(gh release view --repo "$REPO" --json tagName -q '.tagName' 2>/dev/null) || return 1
  local latest_version="${latest_tag#v}"

  # Check if current version matches
  if [ -x "$INSTALL_PATH" ]; then
    local current_version
    current_version=$("$INSTALL_PATH" --version 2>/dev/null | sed -n 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' | head -1 || echo "")
    if [ "$current_version" = "$latest_version" ]; then
      date +%s > "$LAST_CHECK_FILE"
      return 0
    fi
  fi

  # Download and extract
  local asset_name="websearch-cli_${latest_version}_${OS}_${ARCH}.${ARCHIVE_EXT}"
  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap "rm -rf '$tmp_dir'" EXIT

  gh release download "$latest_tag" --repo "$REPO" --pattern "$asset_name" --dir "$tmp_dir" 2>/dev/null || return 1

  if [ "$ARCHIVE_EXT" = "zip" ]; then
    unzip -o "$tmp_dir/$asset_name" -d "$tmp_dir" 2>/dev/null || return 1
  else
    tar -xzf "$tmp_dir/$asset_name" -C "$tmp_dir" 2>/dev/null || return 1
  fi

  mkdir -p "$INSTALL_DIR"
  mv "$tmp_dir/$BIN_NAME" "$INSTALL_PATH"
  chmod +x "$INSTALL_PATH"
  date +%s > "$LAST_CHECK_FILE"

  trap - EXIT
  rm -rf "$tmp_dir"
  return 0
}

# --- Main ---

detect_platform || {
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "# Websearch CLI\n\nUnsupported platform. The websearch plugin requires Linux, macOS, or Windows (x86_64 or arm64)."
  },
  "systemMessage": "WARNING: websearch unsupported platform"
}
EOF
  exit 0
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
fi

# --- Output hook JSON ---

if [ -n "$WEBSEARCH_BIN" ]; then
  HELP=$("$WEBSEARCH_BIN" 2>&1 | head -8)
  STATUS="
🔍 websearch CLI ready${UPDATE_MSG}"
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

jq -n \
  --arg context "$CONTEXT" \
  --arg sysmsg "$STATUS" \
  '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $context
    },
    systemMessage: $sysmsg
  }'
