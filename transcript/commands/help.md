---
description: Show transcript plugin usage guide and available commands
---

# Transcript Plugin - User Guide

The transcript plugin helps you review and analyze your Claude Code conversations by creating beautiful, interactive HTML reports.

## Why Use Transcripts?

- **Review your work** - See exactly what you and Claude discussed and accomplished
- **Share with team** - Export conversations as HTML to share insights with colleagues
- **Learn from sessions** - Study successful prompts and Claude's problem-solving approaches
- **Debug issues** - Review tool calls and outputs when troubleshooting
- **Track progress** - Keep a record of your project's development history

## Quick Start

**View your conversations:**
```
/transcript:list
```
See all available sessions in your project with dates and message counts.

**Create a report for what you're working on now:**
```
/transcript:create
```
Instantly generates an HTML file you can open in your browser.

**Create a report from an older session:**
```
/transcript:create b061b235
```
Use the session ID from the list command (first 8 characters).

## What You Get

Your HTML reports include:

- **Full conversation** - Every message, exactly as it happened
- **Tool usage** - See what commands Claude ran and their results
- **Statistics** - Message counts, token usage, and performance metrics
- **Interactive viewing** - Click to expand/collapse sections for easier reading
- **Easy navigation** - Jump through your conversation quickly

## Tips for Best Results

**Reviewing long sessions:**
- Press the `E` key to expand/collapse all tool details at once
- Click individual tool cards to see specific command details
- Long messages are automatically collapsed - click "Show more" to expand

**Finding specific sessions:**
- Use `/transcript:list` to see your sessions sorted by date
- Session filenames include project name and timestamp for easy identification
- Reports are saved in `.transcripts/` folder (automatically excluded from git)

**Sharing reports:**
- HTML files are self-contained - just send the file
- No internet connection needed to view
- Opens in any modern web browser

## Common Questions

**Where are my reports saved?**
- In `.transcripts/` folder in your project root
- Filename format: `transcript-<session>-<project>-<date>.html`
- Example: `transcript-b061b235-claude-plugins-20251121-154455.html`

**How do I open a report?**
- Double-click the HTML file in your file manager
- Or: `open .transcripts/transcript-*.html` (macOS)
- Or: `xdg-open .transcripts/transcript-*.html` (Linux)

**Can I delete old reports?**
- Yes! They're just HTML files. Delete any you don't need.
- The original transcripts are kept by Claude Code separately

**How do I find a specific conversation?**
- Run `/transcript:list` to see all sessions with dates
- Reports are named with project and timestamp for easy sorting
- Use your file manager to search by date or project name

Need more help? The reports themselves are self-explanatory once you open them!
