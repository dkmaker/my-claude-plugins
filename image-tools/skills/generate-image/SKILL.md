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

### Step 1 — Choose chroma key color

Pick the color that is **most different from the subject's dominant colors**:

| Chroma Key | Prompt color name | Good for | Avoid when subject has |
|------------|------------------|----------|----------------------|
| **Magenta** `#FF00FF` | "magenta" | Most subjects, people, landscapes, animals | Pink/purple/magenta tones |
| **Green** `#00FF00` | "bright green" or "lime green" | Pink/red/purple subjects, sunsets | Plants, nature, green clothing |
| **Blue** `#0000FF` | "bright blue" or "pure blue" | Warm-toned subjects, fire, autumn | Sky, water, blue clothing |
| **Yellow** `#FFFF00` | "bright yellow" | Dark subjects, night scenes, blue items | Gold, sunshine, blonde hair |

**Default to magenta** unless the subject clearly conflicts. When in doubt, think about what the cartoon outlines and dominant fills will be.

### Step 2 — Generate with chroma key

Add to your prompt:
`"on a solid flat [COLOR NAME] (#HEX) background. The background must be perfectly uniform solid [COLOR NAME]. No shadows, gradients, or lighting effects on the background."`

### Step 3 — Remove background with image-tools:manipulate-image

Use the `image-tools:manipulate-image` skill. Note: Gemini won't produce exact colors. Always sample the actual corner pixel first:

```bash
# Sample actual background color
# from PIL import Image; print(Image.open("image.png").getpixel((0,0)))

# Remove chroma key with HSV detection + spill suppression
run.sh alpha <image> --transparent "<actual R,G,B>" --tolerance 15 --feather 40 -o <output>

# Trim empty space
run.sh trim <output> -o <final>
```

### When to use this

User mentions "transparent", "no background", "PNG with alpha", "cutout", or "sticker". **Always tell the user** you're using a chroma key approach since the result won't be transparent until the second step.

## Reference

For detailed setup, troubleshooting, prompt engineering, and file templates, see [SETUP.md](SETUP.md).
