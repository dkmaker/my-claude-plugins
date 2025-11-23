---
description: Show transcript plugin usage guide
---

# Transcript Plugin - Help

## What This Plugin Does

Creates beautiful HTML reports from your current Claude Code conversation.

## Usage

Simply run:

```
/transcript:create
```

This generates an interactive HTML file in `.transcripts/` that you can open in any browser.

## What You Get

Your HTML reports include:

- 💬 **Complete conversation** - Every message in chronological order
- 🛠️ **Tool details** - All commands Claude ran with inputs/outputs
- 📊 **Statistics** - Message counts, token usage, performance metrics
- 🎨 **Interactive UI** - Click to expand/collapse sections
- 🌙 **Dark theme** - Easy on the eyes
- ⌨️ **Keyboard shortcuts** - Press `E` to expand/collapse all tools

## How to View Reports

After creating a report:

**macOS:**
```bash
open .transcripts/transcript-*.html
```

**Linux/WSL:**
```bash
xdg-open .transcripts/transcript-*.html
```

**Windows:**
- Double-click the HTML file in your file manager

## Want a Different Session?

To create a report for a past conversation:

1. Use `/resume <session-id>` to switch to that session
2. Run `/transcript:create` again
3. The report will be created for that session

You can find available session IDs with `/resume` (it shows a list).

## Privacy & Security

- Reports are saved to `.transcripts/`
- This folder is automatically added to `.gitignore`
- Your transcripts won't be committed to git

## Pro Tips

**Viewing tips:**
- Press `E` key in the HTML to expand/collapse all tool details
- Long messages are auto-collapsed - click "Show more" to expand
- Reports are self-contained and work offline

**File organization:**
- Reports are named: `transcript-<session-id>-<project>-<date>.html`
- Easy to find by date or project name in your file manager

That's it! Simple and focused on your current session.
