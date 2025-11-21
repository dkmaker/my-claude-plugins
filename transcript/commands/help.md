---
description: Show transcript plugin usage guide and available commands
---

# Transcript Plugin Help

## Available Commands

### `/transcript:help`
Show this help guide with usage information.

### `/transcript:list`
List all available transcripts in the current project.

**Shows:**
- Session ID (short form - first 8 characters)
- Date and time started
- Git branch
- Total message count
- File location

**Usage:**
```
/transcript:list
```

### `/transcript:create [session-id]`
Create an HTML report for a transcript session.

**Without arguments** - Creates report for current session:
```
/transcript:create
```

**With session ID** - Creates report for specific session (use first 8 characters):
```
/transcript:create 97f85a57
```

**Output:** `.transcripts/<session-id>.html`

**Features:**
- Automatically creates `.transcripts/` folder if needed
- Adds `.transcripts/` to `.gitignore` automatically
- Beautiful styled HTML with interactive elements
- Expandable tool details
- Message statistics and token usage
- Keyboard shortcuts (press E to toggle all tools)

## Environment Variables

The plugin's SessionStart hook sets these environment variables for use in bash commands:

- `CLAUDE_ACTIVE_TRANSCRIPT` - Path to current session transcript file
- `CLAUDE_SESSION_ID` - Current session ID (full UUID)
- `CLAUDE_PROJECT_ROOT` - Project root directory

## Examples

**List transcripts:**
```
/transcript:list
```

**Create report for current session:**
```
/transcript:create
```

**Create report for specific session:**
```
/transcript:create 97f85a57
```

## Troubleshooting

**Commands not found?**
- Make sure the plugin is installed: `/plugin install transcript@claude-plugins`
- Restart Claude Code after installation

**Environment variables empty?**
- Check with: `!echo $CLAUDE_ACTIVE_TRANSCRIPT`
- Reinstall the plugin and restart Claude Code

**Permission errors?**
- Ensure scripts are executable: `chmod +x transcript/scripts/*.sh`

For more information, see the plugin README.
