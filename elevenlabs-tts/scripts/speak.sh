#!/bin/bash
# speak.sh - Queue a message for TTS playback
# Usage: speak "Hello world"
# Returns immediately. Worker speaks asynchronously.

PIPER_DIR="$HOME/.claude/piper-tts"
QUEUE_FILE="$PIPER_DIR/queue"
PID_FILE="$PIPER_DIR/worker.pid"

# Get message from arguments
message="$*"
if [ -z "$message" ]; then
    exit 0
fi

# Ensure queue file exists
touch "$QUEUE_FILE"

# Append message to queue (atomic with flock)
(
    flock 200
    echo "$message" >> "$QUEUE_FILE"
) 200>"$QUEUE_FILE.lock"

# Start worker if not running
start_worker() {
    nohup "$PIPER_DIR/tts-worker.sh" >/dev/null 2>&1 &
}

if [ -f "$PID_FILE" ]; then
    pid=$(cat "$PID_FILE")
    if ! kill -0 "$pid" 2>/dev/null; then
        start_worker
    fi
else
    start_worker
fi
