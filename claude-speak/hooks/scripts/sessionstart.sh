#!/bin/bash
# SessionStart hook for claude-speak plugin
# Downloads the speak binary from dkmaker/claude-speak releases and ensures it's in PATH

REPO="dkmaker/claude-speak"
TTS_DIR="$HOME/.claude/tts"
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

BINARY_PATH="$TTS_DIR/$BINARY_NAME"

# Create directories
mkdir -p "$TTS_DIR" "$HOME/.local/bin"

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
        chmod +x "$BINARY_PATH"
    else
        rm -f "$BINARY_PATH.tmp"
        # Download failed — try to continue with existing binary if any
    fi
fi

# Create symlink in PATH
if [[ "$PLATFORM" != windows-* ]]; then
    ln -sf "$BINARY_PATH" "$HOME/.local/bin/speak"
fi

# Kill stale worker so it restarts with current env
if [ -f "$TTS_DIR/worker.pid" ]; then
    pid=$(cat "$TTS_DIR/worker.pid")
    kill "$pid" 2>/dev/null
    rm -f "$TTS_DIR/worker.pid"
fi

# Determine status
if [ -f "$BINARY_PATH" ] && [ -n "$ELEVENLABS_API_KEY" ]; then
    version=$("$BINARY_PATH" --version 2>/dev/null || echo "unknown")
    status="Voice feedback ready (ElevenLabs, speak v${version})"
elif [ -f "$BINARY_PATH" ]; then
    status="Voice feedback: speak binary installed but ELEVENLABS_API_KEY not set"
else
    status="Voice feedback: Failed to download speak binary. Check https://github.com/${REPO}/releases"
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
