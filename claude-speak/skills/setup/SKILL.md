---
name: setup
description: Configure claude-speak TTS - set up API key, choose voices, test playback, fix PATH issues, and manage settings
disable-model-invocation: true
---

# Claude-Speak Setup Helper

Help the user configure voice feedback for Claude Code.

## First: Check Current Status

```bash
echo "=== claude-speak Status ==="
echo ""

# Check binary location
if [ -f "$HOME/.local/bin/speak" ]; then
  version=$("$HOME/.local/bin/speak" --version 2>/dev/null || echo "unknown")
  echo "✓ Binary installed: ~/.local/bin/speak (v$version)"
else
  echo "✗ Binary not found at ~/.local/bin/speak"
fi

# Check if in PATH
if command -v speak >/dev/null 2>&1; then
  echo "✓ speak command available in PATH"
  echo "  Location: $(which speak)"
else
  echo "✗ speak command NOT in PATH"
fi

# Check API key
if [ -n "$ELEVENLABS_API_KEY" ]; then
  echo "✓ ELEVENLABS_API_KEY is set"
else
  echo "✗ ELEVENLABS_API_KEY is not set"
fi

# Check worker daemon
if [ -f ~/.claude/tts/worker.pid ]; then
  pid=$(cat ~/.claude/tts/worker.pid)
  if kill -0 "$pid" 2>/dev/null; then
    echo "✓ Worker daemon running (PID: $pid)"
  else
    echo "⚠️  Stale PID file (daemon not running)"
  fi
else
  echo "ℹ️  No worker running (starts automatically on first speak command)"
fi
```

Based on the status, proceed with the relevant section below.

---

## Fix PATH Issues

If `speak` is installed but not in PATH, fix it based on your platform:

### Linux / macOS

Check if `~/.local/bin` is in your PATH:

```bash
echo "$PATH" | grep -q "$HOME/.local/bin" && echo "✓ ~/.local/bin is in PATH" || echo "✗ ~/.local/bin NOT in PATH"
```

If not in PATH, add it to your shell profile:

**Bash:**
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Zsh:**
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Fish:**
```bash
fish_add_path ~/.local/bin
```

### Windows

On Windows, the binary is at `%USERPROFILE%\.local\bin\speak.exe`. Add this directory to your user PATH:

**PowerShell (run as Administrator):**
```powershell
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$newPath = "$env:USERPROFILE\.local\bin"
if ($userPath -notlike "*$newPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$newPath", "User")
    Write-Host "Added to PATH. Restart your terminal."
}
```

**Or via GUI:**
1. Search for "Environment Variables" in Start menu
2. Click "Edit environment variables for your account"
3. Select "Path" → "Edit"
4. Click "New" → Add `%USERPROFILE%\.local\bin`
5. Click OK, restart terminal

After fixing PATH, verify:
```bash
speak --version
```

---

## API Key Setup

### Step 1: Get an API key

1. Go to [elevenlabs.io](https://elevenlabs.io) and create an account (free tier available)
2. Click profile icon (bottom-left) → **API Keys**
3. Click **Create API Key** → enable **all permissions** (especially `voices_read` for listing voices)
4. Copy the API key

### Step 2: Store API key securely

**Recommended: Claude Code settings** (never committed to git)

```bash
# Determine which settings file to use
if [ -f .claude/settings.local.json ]; then
  SETTINGS_FILE=".claude/settings.local.json"
elif [ -f ~/.claude/settings.json ]; then
  SETTINGS_FILE="$HOME/.claude/settings.json"
else
  # Create project-local settings
  mkdir -p .claude
  SETTINGS_FILE=".claude/settings.local.json"
  echo '{}' > "$SETTINGS_FILE"
fi

echo "Using settings file: $SETTINGS_FILE"

# Add API key (replace 'sk-...' with your actual key)
jq '.env.ELEVENLABS_API_KEY = "sk-your-api-key-here"' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

echo "✓ API key added to $SETTINGS_FILE"
```

**Ensure .gitignore protects it:**

```bash
if [ "$SETTINGS_FILE" = ".claude/settings.local.json" ]; then
  # Check if already in .gitignore
  if git check-ignore -q .claude/settings.local.json 2>/dev/null; then
    echo "✓ .claude/settings.local.json is already in .gitignore"
  else
    echo "⚠️  Adding .claude/settings.local.json to .gitignore"
    if [ -f .gitignore ]; then
      if ! grep -q "\.claude/settings\.local\.json" .gitignore; then
        echo ".claude/settings.local.json" >> .gitignore
        echo "✓ Added to .gitignore"
      fi
    else
      echo ".claude/settings.local.json" > .gitignore
      echo "✓ Created .gitignore"
    fi
  fi
fi
```

**Alternative: Shell profile** (simpler but less secure)

```bash
# Add to ~/.bashrc or ~/.zshrc
echo 'export ELEVENLABS_API_KEY="sk-your-api-key-here"' >> ~/.bashrc
source ~/.bashrc
```

On Windows PowerShell:
```powershell
[Environment]::SetEnvironmentVariable("ELEVENLABS_API_KEY", "sk-your-api-key-here", "User")
```

### Step 3: Validate API key

Test the API key works:

```bash
curl -s "https://api.elevenlabs.io/v1/voices" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" | \
  python3 -c 'import json,sys; d=json.load(sys.stdin); print("✓ API key valid - found", len(d.get("voices", [])), "voices") if "voices" in d else print("✗ Error:", d.get("detail", {}).get("message", "Unknown error"))'
```

---

## Voice Selection

### List all available voices

```bash
curl -s "https://api.elevenlabs.io/v1/voices" \
  -H "xi-api-key: $ELEVENLABS_API_KEY" | \
  python3 << 'PYEOF'
import json, sys
data = json.load(sys.stdin)
print(f"{'ID':<26} {'Name':<45} {'Gender':<10} {'Age':<15} {'Accent'}")
print("-" * 110)
for v in data["voices"]:
    labels = v.get("labels", {})
    name = v["name"]
    vid = v["voice_id"]
    gender = labels.get("gender", "")
    age = labels.get("age", "")
    accent = labels.get("accent", "")
    print(f"{vid:<26} {name:<45} {gender:<10} {age:<15} {accent}")
PYEOF
```

Or browse voices in your browser: https://elevenlabs.io/voice-library

### Test a voice

```bash
# Test with a specific voice ID (replace with any ID from the list above)
ELEVENLABS_VOICE_ID="IKne3meq5aSn9XLyUdCD" speak "Hello, this is a voice test"
```

Test multiple voices to compare:

```bash
# Replace these IDs with ones from your list
for vid in "IKne3meq5aSn9XLyUdCD" "cjVigY5qzO86Huf0OWal" "nPczCjzI2devNBz1zQrb"; do
  echo "Testing voice: $vid"
  ELEVENLABS_VOICE_ID="$vid" speak "This is a voice preview. Testing the sound quality."
  sleep 8  # Wait for audio to finish
done
```

### Set preferred voice permanently

**In Claude Code settings:**

```bash
jq '.env.ELEVENLABS_VOICE_ID = "IKne3meq5aSn9XLyUdCD"' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
echo "✓ Voice ID saved to $SETTINGS_FILE"
```

**Or in shell profile:**

```bash
echo 'export ELEVENLABS_VOICE_ID="IKne3meq5aSn9XLyUdCD"' >> ~/.bashrc
source ~/.bashrc
```

---

## Optional Configuration

### Change TTS model

```bash
# Default: eleven_flash_v2_5 (fastest)
# Alternative: eleven_multilingual_v2 (better for non-English)

jq '.env.ELEVENLABS_MODEL = "eleven_multilingual_v2"' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
```

---

## Troubleshooting

### Binary won't execute

Check file permissions:
```bash
ls -la ~/.local/bin/speak
chmod +x ~/.local/bin/speak
```

### Download failed

Manual download:
```bash
# Replace {VERSION} and {PLATFORM} with your values
curl -fsSL "https://github.com/dkmaker/claude-speak/releases/download/v{VERSION}/speak-{PLATFORM}" \
  -o ~/.local/bin/speak
chmod +x ~/.local/bin/speak
```

Example for Linux:
```bash
curl -fsSL "https://github.com/dkmaker/claude-speak/releases/download/v1.0.0/speak-linux-amd64" \
  -o ~/.local/bin/speak
chmod +x ~/.local/bin/speak
```

### Check daemon logs

```bash
tail -50 ~/.claude/tts/speak.log
```

### Restart daemon

```bash
speak --stop  # Kill current worker
speak "Test message"  # Starts fresh daemon
```

### Test basic playback

```bash
speak "Testing one two three"
```

If you hear audio, it's working. If not:
- Check API key is valid
- Check you have internet connection
- Check daemon logs at `~/.claude/tts/speak.log`
- On Linux: verify audio device works (`paplay /usr/share/sounds/alsa/Front_Center.wav`)

---

## Quick Setup Checklist

Run through this if setting up from scratch:

1. ✓ Binary installed (`~/.local/bin/speak --version`)
2. ✓ Binary in PATH (`which speak`)
3. ✓ API key obtained (elevenlabs.io)
4. ✓ API key stored (settings.json or shell profile)
5. ✓ API key validated (curl test above)
6. ✓ Voice selected and tested
7. ✓ Test playback works (`speak "hello"`)
