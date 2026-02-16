---
name: setup
description: Configure claude-speak TTS - set up API key, choose voices, test playback, and manage settings
disable-model-invocation: true
---

# Claude-Speak Setup Helper

Help the user configure voice feedback for Claude Code.

## API Key Setup

### Step 1: Check if API key exists

```bash
if [ -n "$ELEVENLABS_API_KEY" ]; then
  echo "✓ ELEVENLABS_API_KEY is set"
else
  echo "✗ ELEVENLABS_API_KEY is not set"
fi
```

### Step 2: If missing, guide user to get one

1. Go to [elevenlabs.io](https://elevenlabs.io) and create an account (free tier available)
2. Click profile icon (bottom-left) → **API Keys**
3. Click **Create API Key** → enable **all permissions** (especially `voices_read` for listing voices)
4. Copy the API key

### Step 3: Store API key securely

**Recommended approach:** Store in Claude Code settings (never committed to git)

Check which settings file to use:
```bash
# Check for project-local settings
if [ -f .claude/settings.local.json ]; then
  SETTINGS_FILE=".claude/settings.local.json"
  echo "Using project settings: $SETTINGS_FILE"
elif [ -f ~/.claude/settings.json ]; then
  SETTINGS_FILE="$HOME/.claude/settings.json"
  echo "Using global settings: $SETTINGS_FILE"
else
  SETTINGS_FILE=".claude/settings.local.json"
  echo "Will create project settings: $SETTINGS_FILE"
fi
```

**Add API key to settings:**

Read the current settings file, add the `env` section with `ELEVENLABS_API_KEY`, and write it back. Use `jq` for safe JSON manipulation:

```bash
# Ensure .claude directory exists for project-local settings
mkdir -p .claude

# Add API key to settings
jq '.env.ELEVENLABS_API_KEY = "sk-..."' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
```

**Ensure .gitignore covers it:**

```bash
# Check if .claude/settings.local.json is in .gitignore
if ! git check-ignore -q .claude/settings.local.json 2>/dev/null; then
  echo "⚠️  .claude/settings.local.json not in .gitignore"
  echo "Add this line to .gitignore:"
  echo "  .claude/settings.local.json"

  # Optionally add it automatically
  if grep -q "\.claude/settings\.local\.json" .gitignore 2>/dev/null; then
    echo "✓ Already in .gitignore"
  else
    echo ".claude/settings.local.json" >> .gitignore
    echo "✓ Added to .gitignore"
  fi
fi
```

**Alternative (simpler but less secure):** Add to shell profile

```bash
# Add to ~/.bashrc or ~/.zshrc
echo 'export ELEVENLABS_API_KEY="sk-..."' >> ~/.bashrc
source ~/.bashrc
```

On Windows PowerShell:
```powershell
[Environment]::SetEnvironmentVariable("ELEVENLABS_API_KEY", "sk-...", "User")
```

### Step 4: Validate API key

Test the API key works:

```bash
curl -s "https://api.elevenlabs.io/v1/voices" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" | \
  python3 -c 'import json,sys; d=json.load(sys.stdin); print("✓ API key valid" if "voices" in d else f"✗ Error: {d.get(\"detail\", {}).get(\"message\", \"Unknown error\")}")'
```

## Voice Selection

### List all available voices

```bash
curl -s "https://api.elevenlabs.io/v1/voices" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" | \
  python3 -c '
import json
data = json.load(open("/dev/stdin"))
print(f"{"ID":<24} {"Name":<45} {"Gender":<10} {"Age":<15} {"Accent"}")
print("-" * 110)
for v in data["voices"]:
    labels = v.get("labels", {})
    name = v["name"]
    vid = v["voice_id"]
    gender = labels.get("gender", "")
    age = labels.get("age", "")
    accent = labels.get("accent", "")
    print(f"{vid:<24} {name:<45} {gender:<10} {age:<15} {accent}")
' | head -30
```

### Browse voices in browser

Send user to: https://elevenlabs.io/voice-library

They can preview voices and copy the voice ID.

### Test a voice

```bash
# Test with a specific voice ID
ELEVENLABS_VOICE_ID="IKne3meq5aSn9XLyUdCD" speak "Hello, this is a voice test"

# Or test multiple voices
for vid in "IKne3meq5aSn9XLyUdCD" "cjVigY5qzO86Huf0OWal" "nPczCjzI2devNBz1zQrb"; do
  echo "Testing voice: $vid"
  ELEVENLABS_VOICE_ID="$vid" speak "This is a voice preview"
  sleep 8  # Wait for audio to finish
done
```

### Set preferred voice permanently

Add to settings file:

```bash
jq '.env.ELEVENLABS_VOICE_ID = "IKne3meq5aSn9XLyUdCD"' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
```

Or add to shell profile:

```bash
echo 'export ELEVENLABS_VOICE_ID="IKne3meq5aSn9XLyUdCD"' >> ~/.bashrc
```

## Optional Configuration

### Change TTS model

```bash
# Default: eleven_flash_v2_5 (fastest)
# Alternative: eleven_multilingual_v2 (better for non-English)

jq '.env.ELEVENLABS_MODEL = "eleven_multilingual_v2"' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
```

## Troubleshooting

### Check if speak binary is installed

```bash
which speak
speak --version
```

Expected: `1.0.0` (or later)

### Check if worker daemon is running

```bash
if [ -f ~/.claude/tts/worker.pid ]; then
  pid=$(cat ~/.claude/tts/worker.pid)
  if kill -0 "$pid" 2>/dev/null; then
    echo "✓ Worker daemon running (PID: $pid)"
  else
    echo "✗ Stale PID file (daemon not running)"
  fi
else
  echo "✗ No worker running"
fi
```

### Check daemon logs

```bash
tail -20 ~/.claude/tts/speak.log
```

### Manually restart daemon

```bash
speak --stop  # Kill current worker
speak "Test message"  # Starts fresh daemon
```

## Summary

1. Get API key from elevenlabs.io with all permissions enabled
2. Store in Claude Code settings (`.claude/settings.local.json` or `~/.claude/settings.json`)
3. Ensure `.claude/settings.local.json` is in `.gitignore`
4. List voices and test them
5. Set preferred voice in settings
6. Use `speak "message"` to test
