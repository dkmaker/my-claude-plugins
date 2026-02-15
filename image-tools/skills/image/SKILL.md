---
name: image
description: Manipulate images - resize, crop, convert, add alpha, transform, compress, and analyze. Use when user needs any image manipulation, format conversion, or image information.
argument-hint: "[operation] [image path] [options]"
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
---

# Image Tools

Swiss army knife for image manipulation powered by Pillow.

## First Use

Run setup check:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/image/scripts/check-setup.sh"
```

If it fails, read the install guide:
`${CLAUDE_PLUGIN_ROOT}/skills/image/scripts/install.md`

## Running Commands

```bash
SCRIPTS="${CLAUDE_PLUGIN_ROOT}/skills/image/scripts"
"$SCRIPTS/run.sh" <command> [args...]
```

## Available Commands

| Command | What it does | Instruction file |
|---------|-------------|-----------------|
| `resize` | Scale to width/height/percentage | [resize-and-scale.md](instructions/resize-and-scale.md) |
| `thumbnail` | Generate max-size thumbnail | [resize-and-scale.md](instructions/resize-and-scale.md) |
| `crop` | Crop by box or center | [crop-and-trim.md](instructions/crop-and-trim.md) |
| `trim` | Auto-trim whitespace borders | [crop-and-trim.md](instructions/crop-and-trim.md) |
| `pad` | Pad to target size with color | [crop-and-trim.md](instructions/crop-and-trim.md) |
| `convert` | Change format (PNG/JPG/WebP) | [convert-and-compress.md](instructions/convert-and-compress.md) |
| `compress` | Reduce file size | [convert-and-compress.md](instructions/convert-and-compress.md) |
| `alpha` | Add/remove/transparent alpha | [alpha-and-composite.md](instructions/alpha-and-composite.md) |
| `composite` | Overlay images | [alpha-and-composite.md](instructions/alpha-and-composite.md) |
| `rotate` | Rotate by degrees | [transform.md](instructions/transform.md) |
| `flip` | Flip horizontal/vertical | [transform.md](instructions/transform.md) |
| `info` | Show dimensions, format, mode | [analyze.md](instructions/analyze.md) |
| `metadata` | Extract EXIF data | [analyze.md](instructions/analyze.md) |

## Workflow

1. Run `check-setup.sh` if this is the first use or you hit errors
2. Read the instruction file for the operation the user needs
3. Run `run.sh <command>` with the right arguments
4. Show the user the result

## Quick Reference

All commands accept: `input` (file or directory for batch), `-o`/`--output`.
