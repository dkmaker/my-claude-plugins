# Design: image-tools Plugin

**Date**: 2026-02-15
**Status**: Approved

## Overview

A swiss army knife plugin for image manipulation in Claude Code. Single skill (`image`) with a modular Python CLI backend powered by Pillow. Handles resize, crop, convert, alpha, transform, and analyze operations.

## Architecture

```
image-tools/
├── .claude-plugin/plugin.json
├── README.md
├── skills/
│   └── image/
│       ├── SKILL.md                        # Lean routing + links to instructions
│       ├── instructions/
│       │   ├── resize-and-scale.md
│       │   ├── crop-and-trim.md
│       │   ├── convert-and-compress.md
│       │   ├── alpha-and-composite.md
│       │   ├── transform.md
│       │   └── analyze.md
│       └── scripts/
│           ├── check-setup.sh              # Validates Python, Pillow, venv
│           ├── install.md                  # Manual fix instructions
│           ├── requirements.txt            # pillow
│           ├── image_tools.py              # Single CLI entrypoint (thin)
│           └── ops/                        # Modular operation modules
│               ├── __init__.py
│               ├── resize.py
│               ├── crop.py
│               ├── convert.py
│               ├── alpha.py
│               ├── transform.py
│               └── analyze.py
```

## Design Decisions

- **Single skill**: One `image` skill handles all operations. Claude reads the user request and picks the right instruction file + subcommand.
- **Modular Python**: Thin `image_tools.py` entrypoint delegates to `ops/*.py` modules. Each module registers its own argparse subcommands. Adding operations = add a module + instruction file.
- **Separate instruction files**: SKILL.md stays lean. Claude only loads the instruction file relevant to the current operation, saving context.
- **Runtime validation**: `check-setup.sh` validates the environment when the skill is invoked (no SessionStart hook). If it fails, Claude reads `install.md` for fix instructions.
- **Venv isolation**: Python dependencies installed in a local venv, following the generate-image plugin pattern.

## Operations

| Module | Subcommands | Description |
|--------|-------------|-------------|
| `ops/resize.py` | `resize`, `thumbnail` | Scale to dimensions, fit/fill/contain modes, batch |
| `ops/crop.py` | `crop`, `trim`, `pad` | Crop by box/center, auto-trim whitespace, add padding |
| `ops/convert.py` | `convert`, `compress` | PNG/JPEG/WebP/AVIF conversion, quality control, batch |
| `ops/alpha.py` | `alpha`, `composite` | Add/remove alpha, make color transparent, overlay |
| `ops/transform.py` | `rotate`, `flip` | Rotate by degrees, flip horizontal/vertical |
| `ops/analyze.py` | `info`, `metadata` | Dimensions, format, color mode, EXIF, batch report |

## CLI Interface

### Common Conventions

- **Input**: First positional arg (file or directory for batch)
- **Output**: `-o`/`--output` (defaults to `<name>_<operation>.<ext>`)
- **Batch**: If input is a directory, process all images
- **Overwrite**: `--overwrite` flag to replace originals
- **Verbose**: `--verbose` for detailed output

### Examples

```bash
# Resize to width, maintain aspect ratio
image_tools.py resize input.png --width 800 -o output.png

# Batch convert folder to WebP
image_tools.py convert ./images/ --format webp --quality 80

# Add alpha channel
image_tools.py alpha input.png --add -o output.png

# Make white transparent
image_tools.py alpha input.png --transparent "255,255,255" --tolerance 30 -o output.png

# Crop center 500x500
image_tools.py crop input.png --center 500x500 -o cropped.png

# Get image info
image_tools.py info input.png

# Auto-trim whitespace
image_tools.py trim input.png -o trimmed.png

# Rotate 90 degrees
image_tools.py rotate input.png --degrees 90 -o rotated.png

# Generate thumbnail
image_tools.py thumbnail input.png --size 200x200 -o thumb.png

# Pad image to square with white background
image_tools.py pad input.png --size 1000x1000 --color "255,255,255" -o padded.png

# Composite overlay on base image
image_tools.py composite base.png overlay.png --position center -o result.png

# Batch info report as JSON
image_tools.py metadata ./images/ --format json -o report.json
```

## check-setup.sh

Validates in order:
1. Python 3.8+ available
2. venv exists at `scripts/venv/` (creates if missing)
3. Pillow installed in venv (installs from requirements.txt if missing)
4. Outputs JSON: `{"status": "ok"}` or `{"status": "error", "message": "..."}`

## SKILL.md Structure

Compact skill file containing:
- Description and trigger conditions
- `allowed-tools: Bash, Read, Write, Glob, AskUserQuestion`
- Step 1: Run `check-setup.sh`, if error read `install.md`
- Step 2: Operation routing table mapping request type → instruction file
- Step 3: Read the relevant instruction file
- Step 4: Run `image_tools.py` with appropriate subcommand

## Dependencies

- Python 3.8+
- Pillow (installed in venv via requirements.txt)
- bash, jq (for check-setup.sh)

## Plugin Metadata

- **Name**: `image-tools`
- **Version**: `1.0.0`
- **Category**: `creative`
- **Keywords**: `image`, `resize`, `crop`, `convert`, `alpha`, `pillow`
