# Generate Image Plugin

AI image generation plugin for Claude Code. Generate high-quality images from text descriptions using various AI models.

## Skills

### gemini

Generate images using Google's Gemini API.

**Invocation:** `/plugin:generate-image:gemini [prompt]`

**Features:**
- High-quality image generation (up to 4K)
- Multiple aspect ratios (1:1, 3:4, 4:3, 2:3, 3:2, 16:9, 9:16, 21:9, 9:21, 32:9, 2:1)
- Fast mode for quick iterations
- Image-to-image editing
- Automatic versioning and folder organization

**Requirements:**
- Python 3.x with venv
- `GEMINI_API_KEY` in `.claude/settings.local.json`

Get your API key at: https://aistudio.google.com/apikey

## Installation

```bash
/plugin install generate-image@my-claude-plugins
```

## Configuration

Add your Gemini API key to your project's `.claude/settings.local.json`:

```json
{
  "env": {
    "GEMINI_API_KEY": "your-api-key-here"
  }
}
```

## Usage Examples

The skill accepts natural language prompts. Claude interprets your request and translates it to appropriate generation parameters.

```
# Interactive mode - will ask clarifying questions
/plugin:generate-image:gemini

# Simple generation
/plugin:generate-image:gemini A sunset over mountains

# Detailed request with specifications
/plugin:generate-image:gemini Professional headshot, business attire, studio lighting, portrait orientation, high quality

# Landscape with specific format
/plugin:generate-image:gemini Mountain landscape at sunset, widescreen cinematic format, 4K quality

# Product photography
/plugin:generate-image:gemini Product photo of a coffee mug on marble surface, square format for social media
```

## Adding More Models

This plugin is designed to support multiple image generation models. To add a new model:

1. Create a new skill directory: `skills/<model-name>/`
2. Add `SKILL.md` with model-specific instructions
3. The skill will be available as `/plugin:generate-image:<model-name>`
