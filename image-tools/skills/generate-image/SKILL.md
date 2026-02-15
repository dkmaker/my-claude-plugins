---
name: generate-image
description: Generate images using Google Gemini API. Use when user asks to generate, create, or make images, pictures, photos, or visual content. Also for editing images, image-to-image generation, or any AI image creation requests.
argument-hint: "[prompt description or 'interactive' for guided mode]"
allowed-tools: Bash, Write, Read, Glob, AskUserQuestion
---

# Gemini Image Generation

Generate high-quality AI images using Google's Gemini API.

## Before First Use

Run the setup check to validate environment:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/generate-image/scripts/check-setup.sh"
```

This validates Python, venv, dependencies, API key, and shows existing images.

## Generation

```bash
SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/skills/generate-image/scripts"
"$SCRIPT_DIR/generate.sh" "your detailed prompt" \
  --aspect-ratio 16:9 \
  --resolution 4K \
  --output images/slug-v1/image.png \
  --user-request "user's original request verbatim" \
  --composition "your reasoning: why you chose this style, composition, colors, etc."
```

**Options:**
- `--aspect-ratio`: 1:1, 3:4, 4:3, 2:3, 3:2, 16:9, 9:16, 21:9, 9:21, 32:9, 2:1 (default: 1:1)
- `--resolution`: 1K, 2K, 4K (default: 2K)
- `--output`: Output filename (default: output.png)
- `--fast`: Use faster model (lower quality)
- `--images`: Reference image(s) for editing/fusion
- `--user-request`: Original user request (ALWAYS pass this)
- `--composition`: Your reasoning/composition notes explaining prompt choices (ALWAYS pass this)
- `--no-metadata`: Skip saving metadata YAML file

**Output:** The script saves `{image_name}_metadata.yaml` alongside the image containing: user request, composition reasoning, final prompt, all parameters, token usage, timestamps, and model response.

## Invocation Modes

**Interactive** (no prompt or vague prompt): Use AskUserQuestion to gather subject, style, aspect ratio, quality.

**Direct** (detailed prompt provided): Execute immediately with sensible defaults.

**Programmatic** (called from workflow): Never block, use defaults, execute immediately.

## Workflow

1. **Check setup**: Run `check-setup.sh` script (especially on first use or errors)
2. **Determine mode**: Interactive vs direct based on prompt clarity
3. **Capture user request**: Save the user's original request verbatim for `--user-request`
4. **Compose prompt**: Enhance the request into a detailed prompt, document your reasoning for `--composition`
5. **Generate slug**: 2-4 word description, lowercase, hyphenated (e.g., `sunset-mountains`)
6. **Check existing**: Look for `images/{slug}-v*` folders for iterations
7. **Generate**: Run script with ALL context flags (`--user-request`, `--composition`)
8. **Report**: Show user the result location and version (metadata auto-saved as `image_metadata.yaml`)

## Interactive Questions (when prompt is vague)

When the user's request lacks detail, use AskUserQuestion to gather:

- **Subject**: Person/Portrait, Product, Landscape/Scene, or Abstract/Artistic
- **Purpose**: Final/Production (4K), Testing/Draft (fast mode), or Web/Social (2K)
- **Style details**: Lighting, colors, mood if relevant

## Iteration Detection

User wants iteration when they say: "another version", "adjust", "modify", "change", "try with", "regenerate".

Find latest version, increment, archive previous in `archive/v{N}/`.

## Transparent Background Requests

**Gemini cannot generate transparent images.** All generated images have a solid background.

When the user wants transparency, use a two-step process: generate with a **chroma key background**, then remove it with the `image-tools:manipulate-image` skill afterwards.

### Step 1 — Analyze subject colors BEFORE choosing chroma key

**MANDATORY**: Before picking a chroma key color, list every color the subject will contain. Think through:
- Skin/body color (e.g., grey hippo, brown dog, pink flamingo)
- Clothing colors (shirt, pants, shoes, accessories)
- Hair/bow/hat colors
- Object colors (bike, tools, props)
- Style colors (cartoon outlines are typically black)

Then pick the chroma key that has **zero overlap** with any of those colors.

### Step 2 — Pick from the chroma key palette

| Chroma Key | Exact RGB | Hex | Gemini keyword | Use when subject does NOT contain |
|------------|-----------|-----|----------------|-----------------------------------|
| **Green** | `RGB(0, 255, 0)` | `#00FF00` | "chroma key green" | Green, lime, emerald, forest tones |
| **Magenta** | `RGB(255, 0, 255)` | `#FF00FF` | "chroma key magenta" | Pink, purple, magenta, violet, fuchsia tones |
| **Blue** | `RGB(0, 0, 255)` | `#0000FF` | "chroma key blue" | Blue, sky blue, navy, cyan, teal tones |
| **Yellow** | `RGB(255, 255, 0)` | `#FFFF00` | "chroma key yellow" | Yellow, gold, blonde, sunshine, amber tones |

**Selection rules:**
1. List ALL expected subject colors first
2. Eliminate any chroma key that overlaps with subject colors
3. From remaining options, pick the one with maximum hue distance from the subject's dominant color
4. **Green is the safest default** — most cartoon/illustration subjects don't contain bright lime green
5. **Never use magenta** for subjects with pink, purple, or magenta clothing/accessories
6. **Never use blue** for sky scenes, water, or subjects wearing blue
7. **Never use yellow** for warm-lit scenes, blonde hair, or gold elements
8. Document your color analysis in the `--composition` flag

### Step 3 — Generate with chroma key prompt

Append this **exact block** to the end of your prompt (replace `[COLOR]`, `[R,G,B]`, `[HEX]`):

```
The subject is placed on a chroma key [COLOR] studio backdrop (RGB [R,G,B], hex [HEX]). Plain studio setting with soft, diffused lighting on the subject only. The background is a perfectly flat, uniform solid [COLOR] with no gradients, no shadows, no texture, no patterns, no depth of field, no bokeh. Every pixel of the background must be the same [COLOR] color (RGB [R,G,B], #[HEX]) from edge to edge with zero variation.
```

**Example for green chroma key:**
```
The subject is placed on a chroma key green studio backdrop (RGB 0,255,0, hex #00FF00). Plain studio setting with soft, diffused lighting on the subject only. The background is a perfectly flat, uniform solid green with no gradients, no shadows, no texture, no patterns, no depth of field, no bokeh. Every pixel of the background must be the same green color (RGB 0,255,0, #00FF00) from edge to edge with zero variation.
```

### Step 4 — Remove background (post-processing)

Gemini won't produce exact RGB values, so always sample the actual corner pixel, then use the manipulate-image scripts directly to remove the background and trim.

```bash
VENV="${CLAUDE_PLUGIN_ROOT}/scripts/venv"
MANIPULATE="${CLAUDE_PLUGIN_ROOT}/skills/manipulate-image/scripts"

# 1. Sample actual background color from corner
"$VENV/bin/python" -c "from PIL import Image; print(Image.open('<image>').getpixel((0,0)))"

# 2. Remove chroma key with HSV detection + spill suppression
"$MANIPULATE/run.sh" alpha <image> --transparent "<actual R,G,B>" --tolerance 15 --feather 40 -o <output>

# 3. Trim empty space
"$MANIPULATE/run.sh" trim <output> -o <final>
```

### When to use this

User mentions "transparent", "no background", "PNG with alpha", "cutout", or "sticker". **Always tell the user** you're using a chroma key approach since the result won't be transparent until the second step.

## Reference

For detailed setup, troubleshooting, prompt engineering, and file templates, see [SETUP.md](SETUP.md).
