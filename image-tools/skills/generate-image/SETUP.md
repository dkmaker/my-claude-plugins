# Gemini Image Generation - Setup & Reference

This document contains detailed setup instructions, troubleshooting, and reference information for the Gemini image generation skill.

## Scripts Location

The generation scripts are located in this skill's `scripts/` directory:
- `${CLAUDE_PLUGIN_ROOT}/skills/generate-image/scripts/check-setup.sh` - Setup validation script
- `${CLAUDE_PLUGIN_ROOT}/skills/generate-image/scripts/generate.sh` - Wrapper script
- `${CLAUDE_PLUGIN_ROOT}/skills/generate-image/scripts/image_gen.py` - Main Python CLI

Dependencies are managed via the shared venv:
- `${CLAUDE_PLUGIN_ROOT}/scripts/requirements.txt` - All plugin dependencies
- `${CLAUDE_PLUGIN_ROOT}/scripts/venv/` - Shared virtual environment

## Manual Setup

### 1. Set Up Shared Environment

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-venv.sh"
```

### 2. Configure API Key

Add your API key to `.claude/settings.local.json`:

```json
{
  "env": {
    "GEMINI_API_KEY": "your-api-key-here"
  }
}
```

Get your API key at: https://aistudio.google.com/apikey

## CLI Options Reference

| Option | Values | Default | Usage |
|--------|--------|---------|-------|
| `--aspect-ratio` | 1:1, 3:4, 4:3, 2:3, 3:2, 4:5, 5:4, 16:9, 9:16, 21:9 | 1:1 | Image dimensions |
| `--resolution` | 1K, 2K, 4K | 2K | Output quality |
| `--output` | filename.png | output.png | Save location |
| `--fast` | flag | (Pro model) | Use standard model |
| `--images` | file paths | none | Reference images |
| `--retries` | number | 3 | Max retry attempts |

## Quality Modes

**High Quality (default - Pro model)**:
- Cinema-grade professional quality
- Perfect for final outputs, client work, high-res prints
- Accurate text rendering in images
- 4K resolution support
- Takes 8-15 seconds

**Fast Mode (--fast)**:
- Good quality for quick iterations
- Perfect for testing ideas, drafts, mockups
- 2K max resolution
- Takes 3-5 seconds

## Prompt Engineering

For best results, structure prompts with:

1. **Subject**: What/who should appear
2. **Action**: What they're doing
3. **Environment**: Setting and context
4. **Style**: Art style or photography type
5. **Lighting**: Lighting conditions
6. **Details**: Specific refinements

**Example**:
```
"Professional corporate headshot of a Danish man in his mid-40s,
IT Director, clean-shaven, navy blue shirt, three-quarter angle,
confident smile, shot with 85mm lens at f/4, soft natural daylight,
modern office background, high-resolution studio quality"
```

## Common Scenarios

### Product Photography
```bash
"$SCRIPT_DIR/generate.sh" "Professional product photo of [item] on marble surface,
studio lighting, commercial photography" --resolution 4K --aspect-ratio 4:3
```

### Landscape
```bash
"$SCRIPT_DIR/generate.sh" "Epic mountain vista, dramatic clouds, golden hour lighting,
cinematic composition" --aspect-ratio 21:9 --resolution 4K
```

### Portrait
```bash
"$SCRIPT_DIR/generate.sh" "Professional headshot, business attire, studio lighting,
photorealistic" --aspect-ratio 2:3 --resolution 4K
```

### Fast Iteration
```bash
"$SCRIPT_DIR/generate.sh" "Quick concept sketch of [subject]" --fast --resolution 1K
```

### Image Editing
```bash
"$SCRIPT_DIR/generate.sh" "Convert to black and white with film grain" \
--images photo.jpg --output edited.png
```

### Multi-Image Fusion
```bash
"$SCRIPT_DIR/generate.sh" "Combine these into an artistic collage" \
--images img1.jpg img2.jpg img3.jpg --output collage.png
```

## Troubleshooting

### "No module named 'google.genai'"
Dependencies not installed. Run the shared setup:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-venv.sh"
```

### "No API key found"
API key not configured. Add to `.claude/settings.local.json` or set `GEMINI_API_KEY` environment variable.

### Rate Limit Errors
The CLI automatically retries with backoff. For frequent limits:
```bash
"$SCRIPT_DIR/generate.sh" "prompt" --retries 5
```

### Slow Generation
- Pro model takes 8-15 seconds (normal)
- Use `--fast` for quicker results (lower quality)
- Lower resolution: `--resolution 1K`

## Image Organization System

All generated images should be organized in a structured folder hierarchy for versioning.

### Directory Structure

```
images/
├── business-headshot-v1/
│   ├── image.png
│   ├── prompt.md
│   ├── composition.md
│   ├── metadata.json
│   └── description.md
├── business-headshot-v2/
│   ├── image.png
│   ├── ...
│   └── archive/
│       └── v1/
└── sunset-landscape-v1/
    └── ...
```

### Folder Naming Convention

Generate folder names as slugs based on the image subject:
- Lowercase, hyphenated
- Descriptive but concise (2-4 words)
- Version suffix (-v1, -v2, -v3...)

**Examples:**
- "Professional headshot" -> `professional-headshot-v1`
- "Product photo of coffee mug" -> `coffee-mug-product-v1`
- "Sunset over mountains" -> `sunset-mountains-v1`

### Metadata Files

| File | Purpose |
|------|---------|
| `image.png` | The generated image |
| `prompt.md` | Exact prompt sent to API |
| `composition.md` | Structured composition breakdown |
| `description.md` | User-friendly description |
| `metadata.json` | Technical metadata |
| `archive/` | Previous versions when iterating |

## Sensible Defaults

When specifications are missing:

| Missing Info | Default Choice | Reasoning |
|--------------|---------------|-----------|
| Aspect ratio | 16:9 | Most versatile for screens |
| Resolution | 2K | Balance of quality/speed |
| Quality mode | High (Pro) | Better to over-deliver |
| Style | Photorealistic | Safe default for most uses |
| Folder slug | Based on subject | Auto-generate from prompt |
| Version | v1 or auto-increment | Check existing folders |
