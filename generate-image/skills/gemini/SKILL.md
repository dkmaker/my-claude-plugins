---
name: gemini
description: Generate images using Google Gemini API. Use when user asks to generate, create, or make images, pictures, photos, or visual content. Also for editing images, image-to-image generation, or any AI image creation requests.
argument-hint: "[prompt description or 'interactive' for guided mode]"
disable-model-invocation: true
allowed-tools: Bash, Write, Read, Glob, AskUserQuestion
---

# Gemini Image Generation

Generate high-quality AI images using Google's Gemini API.

## Before First Use

Run the setup check to validate environment:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/gemini/scripts/check-setup.sh"
```

This validates Python, venv, dependencies, API key, and shows existing images.

## Generation

```bash
SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/skills/gemini/scripts"
"$SCRIPT_DIR/generate.sh" "your prompt" --aspect-ratio 16:9 --resolution 4K --output images/slug-v1/image.png
```

**Options:**
- `--aspect-ratio`: 1:1, 3:4, 4:3, 2:3, 3:2, 16:9, 9:16, 21:9, 9:21, 32:9, 2:1 (default: 1:1)
- `--resolution`: 1K, 2K, 4K (default: 2K)
- `--output`: Output filename (default: output.png)
- `--fast`: Use faster model (lower quality)
- `--images`: Reference image(s) for editing/fusion

## Invocation Modes

**Interactive** (no prompt or vague prompt): Use AskUserQuestion to gather subject, style, aspect ratio, quality.

**Direct** (detailed prompt provided): Execute immediately with sensible defaults.

**Programmatic** (called from workflow): Never block, use defaults, execute immediately.

## Workflow

1. **Check setup**: Run `check-setup.sh` script (especially on first use or errors)
2. **Determine mode**: Interactive vs direct based on prompt clarity
3. **Generate slug**: 2-4 word description, lowercase, hyphenated (e.g., `sunset-mountains`)
4. **Check existing**: Look for `images/{slug}-v*` folders for iterations
5. **Create folder**: `images/{slug}-v{N}/` with image.png, prompt.md, composition.md, metadata.json
6. **Generate**: Run generate script with appropriate options
7. **Report**: Show user the result location and version

## Interactive Questions (when prompt is vague)

When the user's request lacks detail, use AskUserQuestion to gather:

- **Subject**: Person/Portrait, Product, Landscape/Scene, or Abstract/Artistic
- **Purpose**: Final/Production (4K), Testing/Draft (fast mode), or Web/Social (2K)
- **Style details**: Lighting, colors, mood if relevant

## Iteration Detection

User wants iteration when they say: "another version", "adjust", "modify", "change", "try with", "regenerate".

Find latest version, increment, archive previous in `archive/v{N}/`.

## Reference

For detailed setup, troubleshooting, prompt engineering, and file templates, see [SETUP.md](SETUP.md).
