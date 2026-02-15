#!/bin/bash
# TTS Worker - background daemon that reads queue and speaks lines sequentially
# Uses ElevenLabs API (falls back to Piper if no API key)
# Exits after 60s idle. Ensures no overlapping audio and correct ordering.

TTS_DIR="$HOME/.claude/piper-tts"
QUEUE_FILE="$TTS_DIR/queue"
PID_FILE="$TTS_DIR/worker.pid"
IDLE_TIMEOUT=60

# ElevenLabs config
ELEVENLABS_VOICE_ID="${ELEVENLABS_VOICE_ID:-21m00Tcm4TlvDq8ikWAM}"
ELEVENLABS_MODEL="${ELEVENLABS_MODEL:-eleven_flash_v2_5}"

# Piper fallback config
PIPER="$TTS_DIR/venv/bin/piper"
VOICE="$TTS_DIR/voices/en_US-amy-medium.onnx"
LENGTH_SCALE="${PIPER_TTS_SPEED:-0.7}"

# Determine backend
if [ -n "$ELEVENLABS_API_KEY" ]; then
    BACKEND="elevenlabs"
elif [ -f "$PIPER" ]; then
    BACKEND="piper"
else
    echo "No TTS backend available (set ELEVENLABS_API_KEY or install Piper)" >&2
    exit 1
fi

# Write our PID
echo $$ > "$PID_FILE"

# Ensure queue file exists
touch "$QUEUE_FILE"

# Clean up on exit
cleanup() {
    rm -f "$PID_FILE"
    exit 0
}
trap cleanup EXIT INT TERM

speak_elevenlabs() {
    local text="$1"
    local tmpfile
    tmpfile=$(mktemp /tmp/tts-XXXXXX.mp3)

    # Escape text for JSON (handle quotes and backslashes)
    local json_text
    json_text=$(printf '%s' "$text" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null)

    curl -s -X POST "https://api.elevenlabs.io/v1/text-to-speech/${ELEVENLABS_VOICE_ID}" \
        -H "Content-Type: application/json" \
        -H "xi-api-key: ${ELEVENLABS_API_KEY}" \
        -d "{\"text\":${json_text},\"model_id\":\"${ELEVENLABS_MODEL}\"}" \
        --output "$tmpfile" 2>/dev/null

    if [ -s "$tmpfile" ]; then
        paplay "$tmpfile" 2>/dev/null
    fi
    rm -f "$tmpfile"
}

speak_piper() {
    local text="$1"
    local tmpfile
    tmpfile=$(mktemp /tmp/tts-XXXXXX.txt)
    printf '%s' "$text" > "$tmpfile"
    "$PIPER" --model "$VOICE" --length-scale "$LENGTH_SCALE" --input_file "$tmpfile" --output_file "$tmpfile.wav" 2>/dev/null
    paplay "$tmpfile.wav" 2>/dev/null
    rm -f "$tmpfile" "$tmpfile.wav"
}

idle_seconds=0

while true; do
    # Try to read and remove the first line from the queue atomically
    (
        flock 200
        if [ -s "$QUEUE_FILE" ]; then
            head -1 "$QUEUE_FILE"
            tail -n +2 "$QUEUE_FILE" > "$QUEUE_FILE.tmp"
            mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
        fi
    ) 200>"$QUEUE_FILE.lock" > "$TTS_DIR/.current_line"

    line=$(cat "$TTS_DIR/.current_line")

    if [ -n "$line" ]; then
        idle_seconds=0
        if [ "$BACKEND" = "elevenlabs" ]; then
            speak_elevenlabs "$line"
        else
            speak_piper "$line"
        fi
    else
        sleep 0.5
        idle_seconds=$((idle_seconds + 1))
        if [ "$idle_seconds" -ge "$((IDLE_TIMEOUT * 2))" ]; then
            exit 0
        fi
    fi
done
