# Repo Split: claude-speak Binary → Standalone Repo

**Date:** 2026-02-16
**Status:** Approved

## Problem

The Go binary source code for `speak` lives inside the plugin marketplace repo (`my-claude-plugins/elevenlabs-tts/`). When users install the plugin, they pull the entire Go source into their cache — wasteful since they only need the pre-built binary.

## Solution

Split into two repos:

1. **`dkmaker/claude-speak`** — standalone Go repo with source, CI/CD, and binary releases
2. **`dkmaker/my-claude-plugins/claude-speak/`** — thin plugin that downloads the binary from releases

## Repo 1: `dkmaker/claude-speak`

**Location:** `~/code/dkmaker/claude-speak`
**Remote:** `git@github.com:dkmaker/claude-speak.git`

### Contents (from worktree)

```
claude-speak/
├── cmd/speak/
│   ├── main.go
│   ├── detach_unix.go
│   └── detach_windows.go
├── internal/
│   ├── audio/player.go, player_test.go
│   ├── elevenlabs/client.go, client_test.go
│   ├── queue/queue.go, queue_test.go, lock_unix.go, lock_windows.go
│   └── worker/worker.go, worker_test.go, process_unix.go, process_windows.go
├── .github/workflows/release.yml
├── go.mod (module github.com/dkmaker/claude-speak)
├── go.sum
├── Makefile
└── README.md
```

### CI/CD

GitHub Actions workflow triggers on `v*` tags, builds on native runners (ubuntu, macos-13, macos-latest, windows), uploads binaries to GitHub Releases.

## Repo 2: `dkmaker/my-claude-plugins` → `claude-speak/` plugin

### Contents

```
claude-speak/
├── .claude-plugin/
│   └── plugin.json
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       └── sessionstart.sh
└── output-styles/
    └── tts.md
```

### Changes to my-claude-plugins

- Remove: `elevenlabs-tts/` directory entirely
- Add: `claude-speak/` plugin directory
- Update: `.claude-plugin/marketplace.json` (replace elevenlabs-tts with claude-speak)

### SessionStart hook

Downloads binary from `https://github.com/dkmaker/claude-speak/releases/download/v{VERSION}/speak-{os}-{arch}` into `~/.claude/tts/speak`.
