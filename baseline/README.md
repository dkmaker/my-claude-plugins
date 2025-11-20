# Baseline Plugin

Ensures optimal Claude Code defaults and validates required tools automatically.

## What This Plugin Does

Automatically validates your Claude Code environment and applies recommended baseline settings on session start. Runs smart checks every 2 hours to ensure:

- Required tools are installed (jq, git, ripgrep)
- Optimal bash timeout settings are configured
- Non-essential UI messages are disabled
- Custom statusline is configured
- Recommended defaults are applied

## Features

- **Tool Validation** - Checks for critical and optional tools
- **Settings Baseline** - Ensures recommended configuration
- **Smart Throttling** - Only runs every 2 hours to avoid overhead
- **Safe Updates** - Creates rotating backups (keeps last 10)
- **Statusline Integration** - Includes custom statusline script
- **Non-Invasive** - Only updates specific baseline settings, preserves your custom configuration

## Installation

```bash
# Add the marketplace
/plugin marketplace add dkmaker/my-claude-plugins

# Install the baseline plugin
/plugin install my-claude-plugins/baseline
```

Restart Claude Code after installation.

## What Gets Configured

### Settings Applied

The plugin ensures these settings are configured in `~/.claude/settings.json`:

```json
{
  "env": {
    "BASH_DEFAULT_TIMEOUT_MS": "300000",
    "BASH_MAX_TIMEOUT_MS": "600000",
    "CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR": "1",
    "DISABLE_NON_ESSENTIAL_MODEL_CALLS": "1"
  },
  "includeCoAuthoredBy": false,
  "statusLine": {
    "type": "command",
    "command": "<path-to-plugin>/statusline.sh"
  },
  "alwaysThinkingEnabled": false,
  "spinnerTipsEnabled": false
}
```

### Settings Removed

- **`model`** - Removed if present (prevents overriding default model selection)

### Settings Preserved

- **All other settings** - Your custom configuration is completely preserved
- Only the specific baseline values above are added/updated

## How It Works

### SessionStart Hook

The plugin runs a validation script on session start that:

1. **Throttling Check** - Only runs if >2 hours since last check
2. **Tool Validation** - Checks for required tools (jq, git, rg)
3. **Settings Validation** - Compares current settings with baseline
4. **Safe Update** - Creates timestamped backup before changes
5. **Backup Rotation** - Keeps max 10 backups, deletes oldest

### Check Frequency

- **Normal operation**: Checks every 2 hours
- **Critical tools missing**: Checks every session until resolved
- **All OK**: Silent operation (no output)

### Output Behavior

**User notifications (systemMessage):**
- Settings were updated (includes backup location and restart reminder)
- Critical tools missing (jq, git)
- Optional tools missing (ripgrep)

**Claude context (additionalContext):**
- ONLY when critical tools are missing
- Informs Claude that some features may not work

**Silent:**
- Within 2-hour throttle window
- All checks pass, no changes needed

## Included Statusline

The plugin bundles a custom statusline that displays:
- Current model
- Current directory
- Git branch (if in a repo)
- Costs and session info

The statusline path is automatically configured in your settings.

## Tool Requirements

### Critical Tools (Required)

- **jq** - JSON processing (required for settings management)
  ```bash
  sudo apt-get install jq
  ```

- **git** - Version control (required for repository operations)
  ```bash
  sudo apt-get install git
  ```

### Optional Tools (Recommended)

- **ripgrep (rg)** - Fast code search (improves performance)
  ```bash
  sudo apt-get install ripgrep
  ```

## Backup Management

Backups are stored as: `~/.claude/settings.json.backup-YYYY-MM-DD-HHMMSS`

- **Max backups**: 10 (oldest deleted automatically)
- **Created when**: Settings are actually changed
- **Location**: `~/.claude/` directory

To restore a backup:
```bash
cp ~/.claude/settings.json.backup-2025-11-20-193045 ~/.claude/settings.json
```

## Troubleshooting

### Settings Not Applying

After the plugin updates settings, you'll see a message to restart Claude Code:

```bash
# Exit current session
exit

# Start new session
claude
```

### Tools Still Showing as Missing

If you've installed tools but they're still reported as missing:

1. Ensure tools are in your PATH
2. Test: `which jq`, `which git`, `which rg`
3. Restart your shell or reload profile

### Check Status Manually

View your current settings:
```bash
cat ~/.claude/settings.json
```

View recent backups:
```bash
ls -lt ~/.claude/settings.json.backup-* | head -5
```

### Force Recheck

Delete the throttle file to force an immediate check:
```bash
rm ~/.claude/.baseline-last-check
```

Next Claude Code session will run a full validation.

## Uninstalling

If you uninstall this plugin:

1. Your settings remain (plugin doesn't revert changes)
2. Statusline will stop working (path becomes invalid)
3. You can manually restore from a backup if desired

## Version

**1.0.0** - Initial release

## License

See repository license.
