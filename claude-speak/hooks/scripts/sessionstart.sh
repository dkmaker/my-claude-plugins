#!/bin/bash
# SessionStart hook for claude-speak plugin
# Downloads the speak binary from dkmaker/claude-speak releases

REPO="dkmaker/claude-speak"
PLUGIN_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION_FILE="$PLUGIN_DIR/.claude-plugin/plugin.json"

# Read expected version from plugin.json
EXPECTED_VERSION=$(grep -o '"version": *"[^"]*"' "$VERSION_FILE" | head -1 | grep -o '[0-9][^"]*')

# Detect platform
detect_platform() {
    local os arch
    case "$(uname -s 2>/dev/null)" in
        Linux*)  os="linux" ;;
        Darwin*) os="darwin" ;;
        MINGW*|MSYS*|CYGWIN*) os="windows" ;;
        *)
            if [ -n "$WINDIR" ]; then
                os="windows"
            else
                os="linux"  # fallback
            fi
            ;;
    esac

    case "$(uname -m 2>/dev/null)" in
        x86_64|amd64) arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) arch="amd64" ;;  # fallback
    esac

    echo "${os}-${arch}"
}

PLATFORM=$(detect_platform)
BINARY_NAME="speak"
if [[ "$PLATFORM" == windows-* ]]; then
    BINARY_NAME="speak.exe"
fi

# Install directly to ~/.local/bin (standard user binary location)
BINARY_PATH="$HOME/.local/bin/$BINARY_NAME"

# Create directory
mkdir -p "$HOME/.local/bin"

# Also ensure runtime dir exists for queue/worker files
mkdir -p "$HOME/.claude/tts"

# Check if we need to download
need_download=false
if [ ! -f "$BINARY_PATH" ]; then
    need_download=true
elif [ -n "$EXPECTED_VERSION" ]; then
    current_version=$("$BINARY_PATH" --version 2>/dev/null)
    if [ "$current_version" != "$EXPECTED_VERSION" ]; then
        need_download=true
    fi
fi

# Download if needed
if [ "$need_download" = true ] && [ -n "$EXPECTED_VERSION" ]; then
    download_url="https://github.com/${REPO}/releases/download/v${EXPECTED_VERSION}/speak-${PLATFORM}"
    if [[ "$PLATFORM" == windows-* ]]; then
        download_url="${download_url}.exe"
    fi

    if curl -fsSL --connect-timeout 10 "$download_url" -o "$BINARY_PATH.tmp" 2>/dev/null; then
        mv "$BINARY_PATH.tmp" "$BINARY_PATH"
        chmod +x "$BINARY_PATH" 2>/dev/null
    else
        rm -f "$BINARY_PATH.tmp"
        # Download failed — report error below
    fi
fi

# Kill stale worker so it restarts with current env
if [ -f "$HOME/.claude/tts/worker.pid" ]; then
    pid=$(cat "$HOME/.claude/tts/worker.pid")
    kill "$pid" 2>/dev/null
    rm -f "$HOME/.claude/tts/worker.pid"
fi

# Determine status
if [ -f "$BINARY_PATH" ]; then
    version=$("$BINARY_PATH" --version 2>/dev/null || echo "unknown")

    # Check if speak is actually in PATH
    if command -v speak >/dev/null 2>&1; then
        if [ -n "$ELEVENLABS_API_KEY" ]; then
            status="✓ Voice feedback ready (speak v${version})"
        else
            status="⚠️  speak binary installed but ELEVENLABS_API_KEY not set. Run /claude-speak:setup to configure."
        fi
    else
        # Binary exists but not in PATH
        status="⚠️  speak binary downloaded to $BINARY_PATH but not in PATH. Run /claude-speak:setup to fix."
    fi
else
    status="✗ Failed to download speak binary. Run /claude-speak:setup for help or check https://github.com/${REPO}/releases"
fi

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ""
  },
  "systemMessage": "$status"
}
EOF
