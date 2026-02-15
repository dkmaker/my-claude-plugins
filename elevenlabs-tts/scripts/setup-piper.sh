#!/bin/bash
# setup-piper.sh - Ensure piper TTS is installed and ready
# Idempotent - safe to run multiple times

set -e

PIPER_DIR="$HOME/.claude/piper-tts"
VENV_DIR="$PIPER_DIR/venv"
VOICE_DIR="$PIPER_DIR/voices"
VOICE_NAME="en_US-amy-medium"
VOICE_MODEL="$VOICE_DIR/$VOICE_NAME.onnx"
VOICE_CONFIG="$VOICE_DIR/$VOICE_NAME.onnx.json"
VOICE_BASE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium"
SPEAK_LINK="$HOME/.local/bin/speak"

changed=false

# Create directories
mkdir -p "$PIPER_DIR" "$VOICE_DIR" "$HOME/.local/bin"

# Create venv and install piper if not present
if [ ! -f "$VENV_DIR/bin/piper" ]; then
    echo "Installing piper-tts..." >&2
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/pip" install --quiet piper-tts pathvalidate
    changed=true
fi

# Download voice model if not present
if [ ! -f "$VOICE_MODEL" ]; then
    echo "Downloading voice model ($VOICE_NAME)..." >&2
    curl -sL -o "$VOICE_MODEL" "$VOICE_BASE_URL/$VOICE_NAME.onnx"
    curl -sL -o "$VOICE_CONFIG" "$VOICE_BASE_URL/$VOICE_NAME.onnx.json"
    changed=true
fi

# Copy speak.sh and tts-worker.sh to piper dir
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$PLUGIN_DIR/scripts/speak.sh" ]; then
    cp "$PLUGIN_DIR/scripts/speak.sh" "$PIPER_DIR/speak.sh"
    cp "$PLUGIN_DIR/scripts/tts-worker.sh" "$PIPER_DIR/tts-worker.sh"
    chmod +x "$PIPER_DIR/speak.sh" "$PIPER_DIR/tts-worker.sh"
fi

# Create speak symlink in PATH
if [ ! -L "$SPEAK_LINK" ] || [ "$(readlink "$SPEAK_LINK")" != "$PIPER_DIR/speak.sh" ]; then
    ln -sf "$PIPER_DIR/speak.sh" "$SPEAK_LINK"
    changed=true
fi

# Verify paplay is available
if ! command -v paplay >/dev/null 2>&1; then
    echo "WARNING: paplay not found. Install pulseaudio-utils for audio playback." >&2
fi

if [ "$changed" = true ]; then
    echo "Piper TTS setup complete" >&2
fi
