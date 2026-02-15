#!/bin/bash
# SessionStart hook for piper-tts plugin
# Ensures TTS is ready and copies scripts to runtime dir

TTS_DIR="$HOME/.claude/piper-tts"
PLUGIN_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# Create runtime directory
mkdir -p "$TTS_DIR" "$HOME/.local/bin"

# Copy scripts to runtime dir
cp "$PLUGIN_DIR/scripts/speak.sh" "$TTS_DIR/speak.sh"
cp "$PLUGIN_DIR/scripts/tts-worker.sh" "$TTS_DIR/tts-worker.sh"
chmod +x "$TTS_DIR/speak.sh" "$TTS_DIR/tts-worker.sh"

# Create speak symlink in PATH
ln -sf "$TTS_DIR/speak.sh" "$HOME/.local/bin/speak"

# Determine backend and status
if [ -n "$ELEVENLABS_API_KEY" ]; then
    backend="ElevenLabs (eleven_flash_v2_5)"
    status="Piper TTS ready with $backend backend."
elif [ -f "$TTS_DIR/venv/bin/piper" ] && [ -f "$TTS_DIR/voices/en_US-amy-medium.onnx" ]; then
    backend="Piper (local)"
    status="Piper TTS ready with $backend backend. Set ELEVENLABS_API_KEY for faster, higher quality voice."
else
    backend="none"
    status="Piper TTS: No backend available. Set ELEVENLABS_API_KEY or run setup-piper.sh for local fallback."
fi

# Kill stale worker so it restarts with current env
if [ -f "$TTS_DIR/worker.pid" ]; then
    pid=$(cat "$TTS_DIR/worker.pid")
    kill "$pid" 2>/dev/null
    rm -f "$TTS_DIR/worker.pid"
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
