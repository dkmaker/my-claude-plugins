# CLI Installation & Troubleshooting

The websearch CLI is normally auto-installed by the plugin's SessionStart hook. Use this guide when auto-install fails or manual intervention is needed.

## How auto-install works

- On session start, the hook checks `~/.local/bin/websearch`
- If missing or outdated, it downloads the latest release from GitHub
- Uses `gh release download` from `dkmaker/websearch-cli`
- Checks for updates at most once every 24 hours
- Timestamp stored in `~/.claude/.websearch-last-update-check`

## Manual install

```bash
# Get latest release tag
LATEST=$(gh release view --repo dkmaker/websearch-cli --json tagName -q '.tagName')
VERSION="${LATEST#v}"

# Determine platform (linux/darwin) and arch (amd64/arm64)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in x86_64) ARCH="amd64" ;; aarch64|arm64) ARCH="arm64" ;; esac

# Download and install
gh release download "$LATEST" --repo dkmaker/websearch-cli \
  --pattern "websearch-cli_${VERSION}_${OS}_${ARCH}.tar.gz" --dir /tmp
tar -xzf "/tmp/websearch-cli_${VERSION}_${OS}_${ARCH}.tar.gz" -C /tmp
mkdir -p ~/.local/bin
mv /tmp/websearch ~/.local/bin/websearch
chmod +x ~/.local/bin/websearch
```

## Force update

```bash
# Remove the last-check timestamp to force re-check on next session
rm -f ~/.claude/.websearch-last-update-check

# Or manually download latest (see manual install above)
```

## Troubleshooting

### "websearch CLI not found" after install

- Verify `~/.local/bin` is on PATH: `echo $PATH | tr ':' '\n' | grep local`
- If not on PATH, the skill also tries the direct path `~/.local/bin/websearch`
- Check the binary exists and is executable: `ls -la ~/.local/bin/websearch`

### Auto-install fails silently

The hook suppresses errors to avoid blocking session start. To debug:

```bash
# Run the hook script manually with errors visible
bash <plugin-root>/hooks/scripts/check-websearch.sh
```

Common causes:
- `gh` CLI not installed or not authenticated
- No internet access
- GitHub API rate limiting (authenticate `gh` to fix)

### Provider API keys

The websearch CLI needs API keys for its providers:

- **Perplexity**: `PERPLEXITY_API_KEY` environment variable
- **Brave**: `BRAVE_API_KEY` environment variable
- **GitHub**: `GITHUB_TOKEN` (for code/issues search beyond rate limits)

Run `websearch` with no args to see which providers show "ready" vs "no key".

### Custom profiles

Create custom search profiles at `~/.config/websearch/profiles/<name>.yaml`.
Run `websearch --show-profiles` to see available profiles.
