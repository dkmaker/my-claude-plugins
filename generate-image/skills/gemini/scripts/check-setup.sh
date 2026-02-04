#!/bin/bash
# Setup check script for Gemini image generation
# Validates environment, dependencies, and API key

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERRORS=0
WARNINGS=0

echo "=== Gemini Image Generation Setup Check ==="
echo ""

# 1. Check Python
echo -n "Python 3: "
if command -v python3 &>/dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    echo "✓ $PYTHON_VERSION"
else
    echo "✗ NOT FOUND"
    echo "  Please install Python 3"
    ((ERRORS++))
fi

# 2. Check/create venv
echo -n "Virtual environment: "
if [ -d "$SCRIPT_DIR/venv" ]; then
    echo "✓ exists"
else
    echo "creating..."
    python3 -m venv "$SCRIPT_DIR/venv"
    if [ -d "$SCRIPT_DIR/venv" ]; then
        echo "  ✓ created at $SCRIPT_DIR/venv"
    else
        echo "  ✗ failed to create"
        ((ERRORS++))
    fi
fi

# 3. Check/install dependencies
echo -n "Dependencies: "
if "$SCRIPT_DIR/venv/bin/python" -c "from google import genai; from PIL import Image" 2>/dev/null; then
    echo "✓ installed"
else
    echo "installing..."
    "$SCRIPT_DIR/venv/bin/pip" install -q google-genai Pillow 2>/dev/null
    if "$SCRIPT_DIR/venv/bin/python" -c "from google import genai; from PIL import Image" 2>/dev/null; then
        echo "  ✓ installed successfully"
    else
        echo "  ✗ failed to install"
        echo "  Run: $SCRIPT_DIR/venv/bin/pip install google-genai Pillow"
        ((ERRORS++))
    fi
fi

# 4. Check API key
echo -n "GEMINI_API_KEY: "
API_KEY_FOUND=0

# Check environment variable
if [ -n "$GEMINI_API_KEY" ]; then
    echo "✓ found in environment"
    API_KEY_FOUND=1
fi

# Check .claude/settings.local.json
if [ $API_KEY_FOUND -eq 0 ] && [ -f ".claude/settings.local.json" ]; then
    if grep -q "GEMINI_API_KEY" .claude/settings.local.json 2>/dev/null; then
        echo "✓ found in .claude/settings.local.json"
        API_KEY_FOUND=1
    fi
fi

if [ $API_KEY_FOUND -eq 0 ]; then
    echo "✗ NOT FOUND"
    echo ""
    echo "  Please add your API key. Options:"
    echo ""
    echo "  1. Environment variable:"
    echo "     export GEMINI_API_KEY='your-key-here'"
    echo ""
    echo "  2. Add to .claude/settings.local.json:"
    echo "     {"
    echo "       \"env\": {"
    echo "         \"GEMINI_API_KEY\": \"your-key-here\""
    echo "       }"
    echo "     }"
    echo ""
    echo "  Get your API key at: https://aistudio.google.com/apikey"
    ((ERRORS++))
fi

# 5. Check images directory
echo ""
echo "=== Project Status ==="
echo -n "Images directory: "
if [ -d "images" ]; then
    echo "✓ exists"

    # Count existing image folders (portable - works on macOS and Linux)
    IMAGE_COUNT=$(find images -maxdepth 1 -type d -name "*-v*" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$IMAGE_COUNT" -gt 0 ]; then
        echo ""
        echo "Existing compositions ($IMAGE_COUNT):"
        # Portable listing without GNU-specific -printf
        find images -maxdepth 1 -type d -name "*-v*" 2>/dev/null | while read -r dir; do
            basename "$dir"
        done | sort -V | head -20 | sed 's/^/  - /'

        if [ "$IMAGE_COUNT" -gt 20 ]; then
            echo "  ... and $((IMAGE_COUNT - 20)) more"
        fi
    else
        echo "  (no generated images yet)"
    fi
else
    echo "- not created yet (will be created on first generation)"
    ((WARNINGS++))
fi

# 6. Check generate script is executable
echo ""
echo -n "Generate script: "
if [ -x "$SCRIPT_DIR/generate.sh" ]; then
    echo "✓ executable"
else
    chmod +x "$SCRIPT_DIR/generate.sh" 2>/dev/null
    if [ -x "$SCRIPT_DIR/generate.sh" ]; then
        echo "✓ made executable"
    else
        echo "✗ not executable"
        ((ERRORS++))
    fi
fi

# Summary
echo ""
echo "=== Summary ==="
if [ $ERRORS -eq 0 ]; then
    echo "✓ Ready to generate images!"
    echo ""
    echo "Usage: $SCRIPT_DIR/generate.sh \"your prompt\" [options]"
    echo ""
    echo "Options:"
    echo "  --aspect-ratio  1:1, 3:4, 4:3, 2:3, 3:2, 16:9, 9:16, 21:9, 9:21, 32:9, 2:1"
    echo "  --resolution    1K, 2K, 4K (default: 2K)"
    echo "  --output        Output filename (default: output.png)"
    echo "  --fast          Use faster model (lower quality)"
    echo "  --images        Reference image(s) for editing"
    exit 0
else
    echo "✗ $ERRORS error(s) found. Please fix before generating."
    exit 1
fi
