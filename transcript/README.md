# Transcript Plugin

Parse and analyze Claude Code session transcripts with beautiful HTML output.

## Features

- 📜 **List all transcripts** - Browse all your session transcripts
- 📊 **Statistics** - View message counts, token usage, and tool usage
- 🎨 **Beautiful HTML output** - Styled, interactive HTML reports
- 🔍 **Detailed analysis** - See conversation flow, tool usage, and context
- 🚀 **Easy to use** - Simple slash commands integrated into Claude Code

## Installation

Install the plugin from the marketplace:

```bash
/plugin install transcript@claude-plugins
```

After installation, restart Claude Code for the plugin to take effect.

## Usage

The plugin provides three slash commands under the `transcript` namespace:

### `/transcript:help`

Show usage guide and available commands.

```
/transcript:help
```

### `/transcript:list`

List all available transcripts in the current project.

```
/transcript:list
```

Shows:
- Session ID (short form)
- Date and time
- Git branch
- Message count
- File location

### `/transcript:create [session-id]`

Create an HTML report for a transcript session.

```
/transcript:create
```

Without arguments, creates a report for the current session.

With a session ID (first 8 characters), creates a report for that specific session:

```
/transcript:create 97f85a57
```

The report is saved to `.transcripts/<session-id>.html` in your project directory.

**Features:**
- Automatically creates `.transcripts/` folder if needed
- Adds `.transcripts/` to `.gitignore`
- Beautiful, styled HTML with interactive elements
- Expandable tool details
- Message statistics and token usage
- Keyboard shortcuts (press E to toggle all tools)

## HTML Output

The HTML reports provide a beautiful, styled webpage with:

- **Fixed header** - Session information always visible
- **Statistics dashboard** - Message counts, token usage, cache hits
- **Color-coded messages** - User (blue) and assistant (purple) clearly differentiated
- **Expandable tools** - Tool calls with input/output details
- **Smart truncation** - Long messages automatically collapsed with expand option
- **Emoji support** - Full color emoji rendering via Twemoji
- **Keyboard shortcuts** - Press `E` to toggle all tools open/closed
- **Responsive design** - Works on all screen sizes
- **Dark theme** - Optimized for comfortable viewing

## Environment Variables

The SessionStart hook automatically sets these variables:

- `CLAUDE_ACTIVE_TRANSCRIPT` - Path to current session transcript
- `CLAUDE_SESSION_ID` - Current session ID
- `CLAUDE_PROJECT_ROOT` - Project root directory

## Examples

### List all transcripts in current project

```
/transcript:list
```

### Create report for current session

```
/transcript:create
```

Output: `.transcripts/<session-id>.html`

### Create report for specific session

```
/transcript:create 97f85a57
```

Output: `.transcripts/97f85a57.html`

## File Structure

```
transcript/
├── .claude-plugin/
│   └── plugin.json               # Plugin metadata
├── hooks/
│   ├── hooks.json                # Hook configuration
│   └── scripts/
│       └── sessionstart.sh       # Sets env vars and adds scripts/ to PATH
├── scripts/
│   ├── transcript-helper.sh      # Helper for transcript operations
│   ├── normalize-transcript.sh   # JSON normalizer
│   └── render-html-js.sh         # HTML renderer
├── commands/
│   ├── help.md                   # /transcript:help command
│   ├── list.md                   # /transcript:list command
│   └── create.md                 # /transcript:create command
└── README.md                     # This file
```

## How It Works

1. **SessionStart Hook** - Runs on session start, sets environment variables:
   - `CLAUDE_ACTIVE_TRANSCRIPT` - Path to current session transcript
   - `CLAUDE_SESSION_ID` - Current session ID
   - `CLAUDE_PROJECT_ROOT` - Project root directory
   - Adds `scripts/` folder to PATH

2. **Slash Commands** - Three commands for transcript operations:
   - `/transcript:help` - Show usage guide
   - `/transcript:list` - List all transcripts
   - `/transcript:create` - Generate HTML reports

3. **Helper Script** - `transcript-helper.sh` provides transcript metadata and operations

4. **Renderers** - `normalize-transcript.sh` and `render-html-js.sh` convert JSONL to HTML

## Troubleshooting

### Commands not appearing

Make sure the plugin is installed and Claude Code has been restarted:

```bash
/plugin install transcript@claude-plugins
```

Then restart Claude Code.

### Environment variables not set

The SessionStart hook should automatically set `CLAUDE_ACTIVE_TRANSCRIPT`, `CLAUDE_SESSION_ID`, and `CLAUDE_PROJECT_ROOT`. Check by running:

```bash
!echo $CLAUDE_ACTIVE_TRANSCRIPT
```

If empty, reinstall the plugin and restart.

### Permission denied

Make sure all scripts are executable:

```bash
chmod +x transcript/scripts/*.sh
chmod +x transcript/hooks/scripts/*.sh
```

## Development

To test changes locally:

1. Modify scripts or commands
2. Reinstall the plugin:
   ```bash
   /plugin uninstall transcript@claude-plugins
   /plugin install transcript@claude-plugins
   ```
3. Restart Claude Code to activate changes

## License

MIT
