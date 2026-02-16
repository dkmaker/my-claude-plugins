# Cross-Platform TTS Binary (`claude-speak`)

**Date:** 2026-02-16
**Status:** Approved

## Problem

The elevenlabs-tts plugin only works on Linux because it depends on `paplay` (PulseAudio) for audio playback and `flock` for queue locking. macOS and Windows users cannot use the plugin.

## Solution

Replace all shell scripts (`speak.sh`, `tts-worker.sh`, `setup-piper.sh`) with a single Go binary (`speak`) that handles queuing, ElevenLabs API calls, MP3 decoding, and cross-platform audio playback with zero external dependencies.

## Decisions

- **Single binary** replaces all shell scripts (speak.sh, tts-worker.sh, setup-piper.sh)
- **ElevenLabs API only** — no local Piper fallback (simplifies scope)
- **Pure Go audio** via `oto` (no CGo) + `go-mp3` for decoding
- **GitHub Releases** distribution with auto-download in SessionStart hook

## Architecture

```
┌──────────────────────────────────────────────────┐
│                  claude-speak                      │
│                                                    │
│  CLI Interface                                     │
│  ├── speak "text"     → enqueue message            │
│  ├── speak --daemon   → run worker (internal)      │
│  └── speak --stop     → kill worker                │
│                                                    │
│  Queue Manager                                     │
│  ├── File-based queue (~/.claude/tts/queue)        │
│  ├── Cross-platform file locking                   │
│  └── Auto-starts daemon if not running             │
│                                                    │
│  Worker Daemon                                     │
│  ├── Reads queue FIFO                              │
│  ├── Calls ElevenLabs API                          │
│  ├── Decodes MP3 → PCM (go-mp3)                   │
│  ├── Plays audio (oto)                             │
│  └── Auto-exits after 60s idle                     │
│                                                    │
│  Audio Pipeline                                    │
│  ├── MP3 stream from API → go-mp3 decoder          │
│  ├── PCM samples → oto player                      │
│  └── Platform audio: CoreAudio/WASAPI/ALSA         │
└──────────────────────────────────────────────────┘
```

### Binary Modes

1. `speak "Hello"` — client mode: enqueue text, start daemon if needed, exit immediately
2. `speak --daemon` — worker mode: process queue, play audio, idle timeout
3. `speak --stop` — stop the worker
4. `speak --version` — print version

### Go Dependencies

| Library | Purpose |
|---------|---------|
| `github.com/ebitengine/oto/v3` | Cross-platform audio output |
| `github.com/hajimehoshi/go-mp3` | Pure Go MP3 decoder |

### Environment Variables

| Variable | Required | Default |
|----------|----------|---------|
| `ELEVENLABS_API_KEY` | Yes | — |
| `ELEVENLABS_VOICE_ID` | No | `21m00Tcm4TlvDq8ikWAM` (Rachel) |
| `ELEVENLABS_MODEL` | No | `eleven_flash_v2_5` |

### Runtime Files

```
~/.claude/tts/
├── speak          (binary)
├── queue          (message queue)
├── queue.lock     (lock file)
└── worker.pid     (daemon PID)
```

Plus symlink: `~/.local/bin/speak` → `~/.claude/tts/speak`

## Source Layout

```
elevenlabs-tts/
├── .claude-plugin/
│   └── plugin.json
├── cmd/
│   └── speak/
│       └── main.go          # CLI entry point
├── internal/
│   ├── queue/
│   │   └── queue.go         # File-based queue with cross-platform locking
│   ├── worker/
│   │   └── worker.go        # Daemon loop
│   ├── elevenlabs/
│   │   └── client.go        # API client
│   └── audio/
│       └── player.go        # MP3 decode + oto playback
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       └── sessionstart.sh  # Downloads binary, creates symlink
├── output-styles/
│   └── tts.md
├── go.mod
├── go.sum
├── Makefile
└── README.md
```

## Distribution

### Build Targets

- `linux/amd64`, `linux/arm64`
- `darwin/amd64`, `darwin/arm64`
- `windows/amd64`

### GitHub Actions Workflow

1. Trigger on version tag push (`v*`)
2. Cross-compile with `GOOS`/`GOARCH`
3. Upload binaries to GitHub Release

### SessionStart Hook

1. Detect OS and architecture
2. Check if binary exists and version matches
3. Download from GitHub Releases if needed
4. Create symlink in PATH
5. Report status via hook JSON output

## Error Handling

| Scenario | Behavior |
|----------|----------|
| No API key | Error message on speak invocation |
| API failure | Log error, skip message, continue queue |
| Audio device busy | Retry once, then skip |
| Worker crash | Next speak call auto-restarts |
| Network timeout | 10s timeout on API calls, skip on failure |

## Migration

- Remove: `scripts/speak.sh`, `scripts/tts-worker.sh`, `scripts/setup-piper.sh`
- Update: `hooks/scripts/sessionstart.sh` (download binary instead of copying scripts)
- Update: `plugin.json` (bump version)
- Keep: `output-styles/tts.md`, `hooks/hooks.json`
