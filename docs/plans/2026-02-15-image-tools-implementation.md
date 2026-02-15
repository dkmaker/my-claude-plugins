# image-tools Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create an image manipulation plugin with a single smart skill backed by modular Python/Pillow scripts.

**Architecture:** Single skill (`image`) routes to modular `ops/*.py` modules via a thin `image_tools.py` CLI entrypoint. A `check-setup.sh` script validates the environment on first use. Instruction files keep the SKILL.md lean by documenting operations separately.

**Tech Stack:** Python 3 + Pillow, bash, argparse

**Design doc:** `docs/plans/2026-02-15-image-tools-design.md`

---

### Task 1: Scaffold plugin structure and metadata

**Files:**
- Create: `image-tools/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

**Step 1: Create plugin.json**

```json
{
  "name": "image-tools",
  "description": "Swiss army knife for image manipulation: resize, crop, convert, alpha, transform, and analyze images using Pillow.",
  "version": "1.0.0",
  "author": {
    "name": "dkmaker"
  },
  "keywords": ["image", "resize", "crop", "convert", "alpha", "pillow", "manipulation"]
}
```

**Step 2: Register in marketplace.json**

Add this entry to the `plugins` array in `.claude-plugin/marketplace.json`:

```json
{
  "name": "image-tools",
  "source": "./image-tools",
  "description": "Swiss army knife for image manipulation: resize, crop, convert, alpha, transform, and analyze images using Pillow.",
  "version": "1.0.0",
  "keywords": ["image", "resize", "crop", "convert", "alpha", "pillow", "manipulation"],
  "category": "creative"
}
```

**Step 3: Validate JSON**

Run: `jq . image-tools/.claude-plugin/plugin.json && jq . .claude-plugin/marketplace.json`
Expected: Valid JSON output, no errors.

**Step 4: Commit**

```bash
git add image-tools/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "feat(image-tools): scaffold plugin with metadata"
```

---

### Task 2: Create check-setup.sh and install.md

**Files:**
- Create: `image-tools/skills/image/scripts/check-setup.sh`
- Create: `image-tools/skills/image/scripts/install.md`
- Create: `image-tools/skills/image/scripts/requirements.txt`

**Step 1: Create requirements.txt**

```
Pillow>=10.0.0
```

**Step 2: Create check-setup.sh**

Follow the pattern from `generate-image/skills/gemini/scripts/check-setup.sh`. The script must:

1. Check Python 3.8+ exists (`python3 --version`)
2. Check/create venv at `$SCRIPT_DIR/venv`
3. Check/install Pillow from requirements.txt into venv
4. Check the `image_tools.py` entrypoint is present
5. Make `run.sh` executable if it exists
6. Output JSON result: `{"status": "ok"}` or `{"status": "error", "message": "..."}`

```bash
#!/bin/bash
# Setup check for image-tools plugin
# Validates Python, venv, Pillow, and scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERRORS=0

echo "=== Image Tools Setup Check ==="
echo ""

# 1. Check Python 3
echo -n "Python 3: "
if command -v python3 &>/dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    echo "OK $PYTHON_VERSION"
else
    echo "MISSING"
    echo "  Install Python 3.8+"
    ((ERRORS++))
fi

# 2. Check/create venv
echo -n "Virtual environment: "
if [ -d "$SCRIPT_DIR/venv" ]; then
    echo "OK exists"
else
    echo "creating..."
    python3 -m venv "$SCRIPT_DIR/venv"
    if [ -d "$SCRIPT_DIR/venv" ]; then
        echo "  OK created"
    else
        echo "  FAILED to create venv"
        ((ERRORS++))
    fi
fi

# 3. Check/install Pillow
echo -n "Pillow: "
if "$SCRIPT_DIR/venv/bin/python" -c "from PIL import Image; print(Image.__version__)" 2>/dev/null; then
    echo " OK"
else
    echo "installing..."
    "$SCRIPT_DIR/venv/bin/pip" install -q -r "$SCRIPT_DIR/requirements.txt" 2>/dev/null
    if "$SCRIPT_DIR/venv/bin/python" -c "from PIL import Image" 2>/dev/null; then
        echo "  OK installed"
    else
        echo "  FAILED"
        echo "  Run: $SCRIPT_DIR/venv/bin/pip install -r $SCRIPT_DIR/requirements.txt"
        ((ERRORS++))
    fi
fi

# 4. Check entrypoint exists
echo -n "image_tools.py: "
if [ -f "$SCRIPT_DIR/image_tools.py" ]; then
    echo "OK"
else
    echo "MISSING"
    ((ERRORS++))
fi

# 5. Make run.sh executable
if [ -f "$SCRIPT_DIR/run.sh" ] && [ ! -x "$SCRIPT_DIR/run.sh" ]; then
    chmod +x "$SCRIPT_DIR/run.sh"
fi

# Summary
echo ""
if [ $ERRORS -eq 0 ]; then
    echo '{"status": "ok"}'
    exit 0
else
    echo "{\"status\": \"error\", \"message\": \"$ERRORS error(s) found. See output above.\"}"
    exit 1
fi
```

**Step 3: Create install.md**

Document manual installation steps for when check-setup.sh fails:

```markdown
# Image Tools Installation

## Requirements

- Python 3.8+
- pip (comes with Python)

## Manual Setup

1. Install Python 3 if missing:
   - Ubuntu/Debian: `sudo apt install python3 python3-venv`
   - macOS: `brew install python3`
   - Arch: `sudo pacman -S python`

2. Create virtual environment:
   ```bash
   SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT}/skills/image/scripts"
   python3 -m venv "$SCRIPT_DIR/venv"
   ```

3. Install Pillow:
   ```bash
   "$SCRIPT_DIR/venv/bin/pip" install -r "$SCRIPT_DIR/requirements.txt"
   ```

4. Verify:
   ```bash
   "$SCRIPT_DIR/venv/bin/python" -c "from PIL import Image; print(Image.__version__)"
   ```
```

**Step 4: Make check-setup.sh executable and test**

Run: `chmod +x image-tools/skills/image/scripts/check-setup.sh`
Run: `bash image-tools/skills/image/scripts/check-setup.sh`
Expected: Reports errors for missing `image_tools.py` (that's expected — we haven't created it yet). Python and venv should succeed.

**Step 5: Commit**

```bash
git add image-tools/skills/image/scripts/
git commit -m "feat(image-tools): add setup validation and install instructions"
```

---

### Task 3: Create the Python CLI entrypoint and ops package

**Files:**
- Create: `image-tools/skills/image/scripts/image_tools.py`
- Create: `image-tools/skills/image/scripts/run.sh`
- Create: `image-tools/skills/image/scripts/ops/__init__.py`

**Step 1: Create ops/__init__.py**

This module auto-discovers and registers all operation modules:

```python
"""Operation modules for image-tools. Each module registers subcommands."""

import importlib
import pkgutil
import os


def register_all(subparsers):
    """Auto-discover and register all ops modules."""
    ops_dir = os.path.dirname(__file__)
    for finder, name, ispkg in pkgutil.iter_modules([ops_dir]):
        if name.startswith("_"):
            continue
        module = importlib.import_module(f"ops.{name}")
        if hasattr(module, "register"):
            module.register(subparsers)
```

**Step 2: Create image_tools.py**

Thin entrypoint that sets up argparse and delegates to ops modules:

```python
#!/usr/bin/env python3
"""image-tools: Swiss army knife for image manipulation."""

import argparse
import sys
import os

# Add script directory to path so ops package is importable
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ops import register_all


def main():
    parser = argparse.ArgumentParser(
        prog="image_tools",
        description="Swiss army knife for image manipulation",
    )
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")

    subparsers = parser.add_subparsers(dest="command", help="Operation to perform")
    register_all(subparsers)

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(1)

    # Each subcommand sets a 'func' attribute via set_defaults
    args.func(args)


if __name__ == "__main__":
    main()
```

**Step 3: Create run.sh**

Wrapper to invoke with venv Python (following generate-image pattern):

```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/venv/bin/python" "$SCRIPT_DIR/image_tools.py" "$@"
```

**Step 4: Make run.sh executable**

Run: `chmod +x image-tools/skills/image/scripts/run.sh`

**Step 5: Test entrypoint shows help**

Run: `bash image-tools/skills/image/scripts/check-setup.sh && image-tools/skills/image/scripts/run.sh --help`
Expected: Help text with no subcommands yet (they'll be added in subsequent tasks).

**Step 6: Commit**

```bash
git add image-tools/skills/image/scripts/
git commit -m "feat(image-tools): add CLI entrypoint with auto-discovery"
```

---

### Task 4: Implement ops/resize.py

**Files:**
- Create: `image-tools/skills/image/scripts/ops/resize.py`

**Step 1: Create the module**

Provides `resize` and `thumbnail` subcommands:

```python
"""Resize and scale operations."""

import os
from PIL import Image


def _parse_size(size_str):
    """Parse 'WxH' or 'W' into (width, height) or (width, None)."""
    if "x" in size_str.lower():
        parts = size_str.lower().split("x")
        return int(parts[0]), int(parts[1])
    return int(size_str), None


def _output_path(input_path, suffix, output=None):
    """Generate output path: explicit -o, or append suffix before extension."""
    if output:
        return output
    base, ext = os.path.splitext(input_path)
    return f"{base}_{suffix}{ext}"


def _collect_images(path):
    """If path is a directory, return all image files. Otherwise return [path]."""
    EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tiff", ".tif", ".gif"}
    if os.path.isdir(path):
        files = []
        for f in sorted(os.listdir(path)):
            if os.path.splitext(f)[1].lower() in EXTS:
                files.append(os.path.join(path, f))
        return files
    return [path]


def cmd_resize(args):
    """Resize image(s) to specified dimensions."""
    files = _collect_images(args.input)

    for filepath in files:
        img = Image.open(filepath)
        orig_w, orig_h = img.size

        if args.width and args.height:
            new_size = (args.width, args.height)
        elif args.width:
            ratio = args.width / orig_w
            new_size = (args.width, round(orig_h * ratio))
        elif args.height:
            ratio = args.height / orig_h
            new_size = (round(orig_w * ratio), args.height)
        elif args.scale:
            factor = args.scale / 100.0
            new_size = (round(orig_w * factor), round(orig_h * factor))
        else:
            print(f"Error: specify --width, --height, or --scale")
            return

        resample = Image.LANCZOS
        result = img.resize(new_size, resample)

        out = _output_path(filepath, f"{new_size[0]}x{new_size[1]}", args.output if len(files) == 1 else None)
        os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
        result.save(out)
        print(f"{filepath}: {orig_w}x{orig_h} -> {new_size[0]}x{new_size[1]} => {out}")


def cmd_thumbnail(args):
    """Generate thumbnail with max size constraint."""
    files = _collect_images(args.input)
    max_w, max_h = _parse_size(args.size)
    if max_h is None:
        max_h = max_w

    for filepath in files:
        img = Image.open(filepath)
        img.thumbnail((max_w, max_h), Image.LANCZOS)
        out = _output_path(filepath, "thumb", args.output if len(files) == 1 else None)
        os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
        img.save(out)
        print(f"{filepath}: -> {img.size[0]}x{img.size[1]} => {out}")


def register(subparsers):
    # resize
    p = subparsers.add_parser("resize", help="Resize image(s)")
    p.add_argument("input", help="Image file or directory")
    p.add_argument("-o", "--output", help="Output path")
    p.add_argument("--width", type=int, help="Target width (px)")
    p.add_argument("--height", type=int, help="Target height (px)")
    p.add_argument("--scale", type=float, help="Scale percentage (e.g. 50 for half)")
    p.add_argument("--overwrite", action="store_true", help="Overwrite input file")
    p.set_defaults(func=cmd_resize)

    # thumbnail
    p = subparsers.add_parser("thumbnail", help="Generate thumbnail")
    p.add_argument("input", help="Image file or directory")
    p.add_argument("--size", required=True, help="Max size as WxH or W (e.g. 200x200)")
    p.add_argument("-o", "--output", help="Output path")
    p.set_defaults(func=cmd_thumbnail)
```

**Step 2: Test resize**

Create a test image and run:
```bash
# Create a test image
image-tools/skills/image/scripts/venv/bin/python -c "
from PIL import Image
img = Image.new('RGB', (1000, 800), 'red')
img.save('/tmp/test_img.png')
print('Created 1000x800 test image')
"

# Test resize by width
image-tools/skills/image/scripts/run.sh resize /tmp/test_img.png --width 500 -o /tmp/test_resized.png

# Test thumbnail
image-tools/skills/image/scripts/run.sh thumbnail /tmp/test_img.png --size 200x200 -o /tmp/test_thumb.png
```

Expected: Output files at correct dimensions.

**Step 3: Verify output dimensions**

```bash
image-tools/skills/image/scripts/venv/bin/python -c "
from PIL import Image
for f in ['/tmp/test_resized.png', '/tmp/test_thumb.png']:
    img = Image.open(f)
    print(f'{f}: {img.size}')
"
```

Expected: `test_resized.png: (500, 400)`, `test_thumb.png: (200, 160)`

**Step 4: Commit**

```bash
git add image-tools/skills/image/scripts/ops/resize.py
git commit -m "feat(image-tools): add resize and thumbnail operations"
```

---

### Task 5: Implement ops/crop.py

**Files:**
- Create: `image-tools/skills/image/scripts/ops/crop.py`

**Step 1: Create the module**

Provides `crop`, `trim`, and `pad` subcommands:

```python
"""Crop, trim, and pad operations."""

import os
from PIL import Image, ImageChops


def _output_path(input_path, suffix, output=None):
    if output:
        return output
    base, ext = os.path.splitext(input_path)
    return f"{base}_{suffix}{ext}"


def _parse_color(color_str):
    """Parse 'R,G,B' or 'R,G,B,A' string to tuple."""
    parts = [int(x.strip()) for x in color_str.split(",")]
    return tuple(parts)


def _parse_size(size_str):
    """Parse 'WxH' into (width, height)."""
    parts = size_str.lower().split("x")
    return int(parts[0]), int(parts[1])


def cmd_crop(args):
    """Crop image by box coordinates or center crop."""
    img = Image.open(args.input)
    w, h = img.size

    if args.box:
        # --box left,top,right,bottom
        parts = [int(x.strip()) for x in args.box.split(",")]
        box = tuple(parts)
    elif args.center:
        cw, ch = _parse_size(args.center)
        left = (w - cw) // 2
        top = (h - ch) // 2
        box = (left, top, left + cw, top + ch)
    else:
        print("Error: specify --box or --center")
        return

    result = img.crop(box)
    out = _output_path(args.input, "cropped", args.output)
    result.save(out)
    print(f"{args.input}: {w}x{h} -> {result.size[0]}x{result.size[1]} => {out}")


def cmd_trim(args):
    """Auto-trim whitespace/uniform borders from image."""
    img = Image.open(args.input)

    if args.color:
        bg_color = _parse_color(args.color)
    else:
        # Sample corner pixel as background color
        bg_color = img.getpixel((0, 0))

    # Create background image of same size and mode
    if img.mode == "RGBA":
        bg = Image.new("RGBA", img.size, bg_color)
    else:
        bg = Image.new(img.mode, img.size, bg_color[:len(img.getpixel((0, 0)))] if isinstance(bg_color, tuple) else bg_color)

    diff = ImageChops.difference(img, bg)
    bbox = diff.getbbox()

    if bbox:
        result = img.crop(bbox)
        out = _output_path(args.input, "trimmed", args.output)
        result.save(out)
        print(f"{args.input}: {img.size[0]}x{img.size[1]} -> {result.size[0]}x{result.size[1]} => {out}")
    else:
        print(f"{args.input}: nothing to trim (image is uniform)")


def cmd_pad(args):
    """Pad image to target size with background color."""
    img = Image.open(args.input)
    target_w, target_h = _parse_size(args.size)
    color = _parse_color(args.color) if args.color else (255, 255, 255)

    if img.mode == "RGBA":
        color = color + (255,) if len(color) == 3 else color
        result = Image.new("RGBA", (target_w, target_h), color)
    else:
        result = Image.new(img.mode, (target_w, target_h), color[:3])

    # Center the image on the padded canvas
    x = (target_w - img.size[0]) // 2
    y = (target_h - img.size[1]) // 2
    result.paste(img, (x, y))

    out = _output_path(args.input, "padded", args.output)
    result.save(out)
    print(f"{args.input}: {img.size[0]}x{img.size[1]} -> {target_w}x{target_h} => {out}")


def register(subparsers):
    # crop
    p = subparsers.add_parser("crop", help="Crop image")
    p.add_argument("input", help="Image file")
    p.add_argument("-o", "--output", help="Output path")
    p.add_argument("--box", help="Crop box as left,top,right,bottom")
    p.add_argument("--center", help="Center crop as WxH")
    p.set_defaults(func=cmd_crop)

    # trim
    p = subparsers.add_parser("trim", help="Auto-trim borders")
    p.add_argument("input", help="Image file")
    p.add_argument("-o", "--output", help="Output path")
    p.add_argument("--color", help="Background color to trim as R,G,B (default: sample corner)")
    p.set_defaults(func=cmd_trim)

    # pad
    p = subparsers.add_parser("pad", help="Pad image to target size")
    p.add_argument("input", help="Image file")
    p.add_argument("--size", required=True, help="Target size as WxH")
    p.add_argument("--color", help="Padding color as R,G,B (default: 255,255,255)")
    p.add_argument("-o", "--output", help="Output path")
    p.set_defaults(func=cmd_pad)
```

**Step 2: Test crop, trim, and pad**

```bash
# Test center crop
image-tools/skills/image/scripts/run.sh crop /tmp/test_img.png --center 500x400 -o /tmp/test_cropped.png

# Test pad
image-tools/skills/image/scripts/run.sh pad /tmp/test_img.png --size 1200x1200 --color "0,0,0" -o /tmp/test_padded.png

# Verify
image-tools/skills/image/scripts/venv/bin/python -c "
from PIL import Image
for f in ['/tmp/test_cropped.png', '/tmp/test_padded.png']:
    print(f'{f}: {Image.open(f).size}')
"
```

Expected: `test_cropped.png: (500, 400)`, `test_padded.png: (1200, 1200)`

**Step 3: Commit**

```bash
git add image-tools/skills/image/scripts/ops/crop.py
git commit -m "feat(image-tools): add crop, trim, and pad operations"
```

---

### Task 6: Implement ops/convert.py

**Files:**
- Create: `image-tools/skills/image/scripts/ops/convert.py`

**Step 1: Create the module**

Provides `convert` and `compress` subcommands:

```python
"""Format conversion and compression operations."""

import os
from PIL import Image


def _collect_images(path):
    EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tiff", ".tif", ".gif"}
    if os.path.isdir(path):
        files = []
        for f in sorted(os.listdir(path)):
            if os.path.splitext(f)[1].lower() in EXTS:
                files.append(os.path.join(path, f))
        return files
    return [path]


FORMAT_MAP = {
    "png": "PNG",
    "jpg": "JPEG",
    "jpeg": "JPEG",
    "webp": "WEBP",
    "bmp": "BMP",
    "tiff": "TIFF",
    "gif": "GIF",
}


def cmd_convert(args):
    """Convert image(s) to a different format."""
    files = _collect_images(args.input)
    fmt = args.format.lower()
    pil_format = FORMAT_MAP.get(fmt)
    if not pil_format:
        print(f"Error: unsupported format '{fmt}'. Supported: {', '.join(FORMAT_MAP.keys())}")
        return

    save_kwargs = {}
    if args.quality and pil_format in ("JPEG", "WEBP"):
        save_kwargs["quality"] = args.quality
    if pil_format == "PNG" and args.quality:
        # PNG uses compress_level 0-9
        save_kwargs["compress_level"] = min(9, max(0, (100 - args.quality) // 10))

    for filepath in files:
        img = Image.open(filepath)

        # Handle mode conversion for JPEG (no alpha)
        if pil_format == "JPEG" and img.mode in ("RGBA", "P", "LA"):
            img = img.convert("RGB")

        base = os.path.splitext(filepath)[0]
        out = args.output if (args.output and len(files) == 1) else f"{base}.{fmt}"
        os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
        img.save(out, pil_format, **save_kwargs)

        orig_size = os.path.getsize(filepath)
        new_size = os.path.getsize(out)
        ratio = ((orig_size - new_size) / orig_size) * 100 if orig_size > 0 else 0
        print(f"{filepath} -> {out} ({orig_size:,}B -> {new_size:,}B, {ratio:+.1f}%)")


def cmd_compress(args):
    """Compress image by adjusting quality."""
    files = _collect_images(args.input)
    quality = args.quality or 80

    for filepath in files:
        img = Image.open(filepath)
        ext = os.path.splitext(filepath)[1].lower()
        pil_format = FORMAT_MAP.get(ext.lstrip("."), "PNG")

        if pil_format == "JPEG" and img.mode in ("RGBA", "P", "LA"):
            img = img.convert("RGB")

        base, orig_ext = os.path.splitext(filepath)
        out = args.output if (args.output and len(files) == 1) else f"{base}_compressed{orig_ext}"

        save_kwargs = {}
        if pil_format in ("JPEG", "WEBP"):
            save_kwargs["quality"] = quality
            save_kwargs["optimize"] = True
        elif pil_format == "PNG":
            save_kwargs["optimize"] = True

        img.save(out, pil_format, **save_kwargs)

        orig_size = os.path.getsize(filepath)
        new_size = os.path.getsize(out)
        ratio = ((orig_size - new_size) / orig_size) * 100 if orig_size > 0 else 0
        print(f"{filepath} -> {out} ({orig_size:,}B -> {new_size:,}B, {ratio:+.1f}%)")


def register(subparsers):
    # convert
    p = subparsers.add_parser("convert", help="Convert image format")
    p.add_argument("input", help="Image file or directory")
    p.add_argument("--format", "-f", required=True, help="Target format: png, jpg, webp, bmp, tiff, gif")
    p.add_argument("--quality", "-q", type=int, help="Quality 1-100 (for JPEG/WebP)")
    p.add_argument("-o", "--output", help="Output path")
    p.set_defaults(func=cmd_convert)

    # compress
    p = subparsers.add_parser("compress", help="Compress image")
    p.add_argument("input", help="Image file or directory")
    p.add_argument("--quality", "-q", type=int, default=80, help="Quality 1-100 (default: 80)")
    p.add_argument("-o", "--output", help="Output path")
    p.set_defaults(func=cmd_compress)
```

**Step 2: Test convert and compress**

```bash
# Convert PNG to WebP
image-tools/skills/image/scripts/run.sh convert /tmp/test_img.png --format webp --quality 80 -o /tmp/test_converted.webp

# Compress
image-tools/skills/image/scripts/run.sh compress /tmp/test_img.png --quality 60 -o /tmp/test_compressed.png

# Verify files exist and show sizes
ls -la /tmp/test_converted.webp /tmp/test_compressed.png
```

Expected: Both files exist, WebP should be smaller than original PNG.

**Step 3: Commit**

```bash
git add image-tools/skills/image/scripts/ops/convert.py
git commit -m "feat(image-tools): add convert and compress operations"
```

---

### Task 7: Implement ops/alpha.py

**Files:**
- Create: `image-tools/skills/image/scripts/ops/alpha.py`

**Step 1: Create the module**

Provides `alpha` and `composite` subcommands:

```python
"""Alpha channel and compositing operations."""

import os
from PIL import Image


def _output_path(input_path, suffix, output=None):
    if output:
        return output
    base, ext = os.path.splitext(input_path)
    # Alpha operations produce PNG (need transparency)
    if ext.lower() in (".jpg", ".jpeg"):
        ext = ".png"
    return f"{base}_{suffix}{ext}"


def _parse_color(color_str):
    parts = [int(x.strip()) for x in color_str.split(",")]
    return tuple(parts)


def cmd_alpha(args):
    """Manage alpha channel: add, remove, or make color transparent."""
    img = Image.open(args.input)

    if args.add:
        result = img.convert("RGBA")
        out = _output_path(args.input, "alpha", args.output)
        result.save(out)
        print(f"{args.input}: added alpha channel => {out}")

    elif args.remove:
        if img.mode == "RGBA":
            bg = Image.new("RGB", img.size, _parse_color(args.background) if args.background else (255, 255, 255))
            bg.paste(img, mask=img.split()[3])
            result = bg
        else:
            result = img.convert("RGB")
        out = _output_path(args.input, "noalpha", args.output)
        result.save(out)
        print(f"{args.input}: removed alpha channel => {out}")

    elif args.transparent:
        target = _parse_color(args.transparent)
        tolerance = args.tolerance or 0
        img = img.convert("RGBA")
        data = img.getdata()
        new_data = []
        count = 0
        for pixel in data:
            r, g, b = pixel[:3]
            if (abs(r - target[0]) <= tolerance and
                abs(g - target[1]) <= tolerance and
                abs(b - target[2]) <= tolerance):
                new_data.append((r, g, b, 0))
                count += 1
            else:
                new_data.append(pixel)
        img.putdata(new_data)
        out = _output_path(args.input, "transparent", args.output)
        img.save(out)
        print(f"{args.input}: made {count} pixels transparent => {out}")

    else:
        print("Error: specify --add, --remove, or --transparent R,G,B")


def cmd_composite(args):
    """Overlay one image on another."""
    base = Image.open(args.base).convert("RGBA")
    overlay = Image.open(args.overlay).convert("RGBA")

    # Parse position
    if args.position == "center":
        x = (base.size[0] - overlay.size[0]) // 2
        y = (base.size[1] - overlay.size[1]) // 2
    elif args.position:
        parts = args.position.split(",")
        x, y = int(parts[0]), int(parts[1])
    else:
        x, y = 0, 0

    # Resize overlay if requested
    if args.overlay_size:
        ow, oh = [int(x) for x in args.overlay_size.lower().split("x")]
        overlay = overlay.resize((ow, oh), Image.LANCZOS)

    result = base.copy()
    result.paste(overlay, (x, y), overlay)

    out = args.output or _output_path(args.base, "composite")
    result.save(out)
    print(f"Composited {args.overlay} onto {args.base} at ({x},{y}) => {out}")


def register(subparsers):
    # alpha
    p = subparsers.add_parser("alpha", help="Manage alpha channel")
    p.add_argument("input", help="Image file")
    p.add_argument("-o", "--output", help="Output path")
    p.add_argument("--add", action="store_true", help="Add alpha channel")
    p.add_argument("--remove", action="store_true", help="Remove alpha (flatten)")
    p.add_argument("--background", help="Background color for --remove as R,G,B (default: white)")
    p.add_argument("--transparent", help="Make color transparent as R,G,B")
    p.add_argument("--tolerance", type=int, default=0, help="Color match tolerance (0-255)")
    p.set_defaults(func=cmd_alpha)

    # composite
    p = subparsers.add_parser("composite", help="Overlay images")
    p.add_argument("base", help="Base image file")
    p.add_argument("overlay", help="Overlay image file")
    p.add_argument("-o", "--output", help="Output path")
    p.add_argument("--position", default="center", help="Position: center or X,Y")
    p.add_argument("--overlay-size", help="Resize overlay to WxH before compositing")
    p.set_defaults(func=cmd_composite)
```

**Step 2: Test alpha operations**

```bash
# Add alpha channel
image-tools/skills/image/scripts/run.sh alpha /tmp/test_img.png --add -o /tmp/test_alpha.png

# Make red transparent (our test image is all red)
image-tools/skills/image/scripts/run.sh alpha /tmp/test_img.png --transparent "255,0,0" --tolerance 10 -o /tmp/test_transp.png

# Verify modes
image-tools/skills/image/scripts/venv/bin/python -c "
from PIL import Image
for f in ['/tmp/test_alpha.png', '/tmp/test_transp.png']:
    img = Image.open(f)
    print(f'{f}: mode={img.mode}, size={img.size}')
"
```

Expected: Both files in RGBA mode.

**Step 3: Commit**

```bash
git add image-tools/skills/image/scripts/ops/alpha.py
git commit -m "feat(image-tools): add alpha channel and composite operations"
```

---

### Task 8: Implement ops/transform.py

**Files:**
- Create: `image-tools/skills/image/scripts/ops/transform.py`

**Step 1: Create the module**

Provides `rotate` and `flip` subcommands:

```python
"""Transform operations: rotate, flip."""

import os
from PIL import Image


def _output_path(input_path, suffix, output=None):
    if output:
        return output
    base, ext = os.path.splitext(input_path)
    return f"{base}_{suffix}{ext}"


def cmd_rotate(args):
    """Rotate image by degrees."""
    img = Image.open(args.input)
    expand = not args.no_expand
    fill = (0, 0, 0, 0) if img.mode == "RGBA" else (0, 0, 0)

    result = img.rotate(args.degrees, expand=expand, resample=Image.BICUBIC, fillcolor=fill)
    out = _output_path(args.input, f"rot{args.degrees}", args.output)
    result.save(out)
    print(f"{args.input}: rotated {args.degrees}° => {out} ({result.size[0]}x{result.size[1]})")


def cmd_flip(args):
    """Flip image horizontally or vertically."""
    img = Image.open(args.input)

    if args.direction in ("h", "horizontal"):
        result = img.transpose(Image.FLIP_LEFT_RIGHT)
        label = "horizontal"
    elif args.direction in ("v", "vertical"):
        result = img.transpose(Image.FLIP_TOP_BOTTOM)
        label = "vertical"
    else:
        print(f"Error: direction must be 'h'/'horizontal' or 'v'/'vertical'")
        return

    out = _output_path(args.input, f"flip_{label}", args.output)
    result.save(out)
    print(f"{args.input}: flipped {label} => {out}")


def register(subparsers):
    # rotate
    p = subparsers.add_parser("rotate", help="Rotate image")
    p.add_argument("input", help="Image file")
    p.add_argument("--degrees", "-d", type=float, required=True, help="Rotation angle in degrees (CCW)")
    p.add_argument("--no-expand", action="store_true", help="Don't expand canvas to fit rotated image")
    p.add_argument("-o", "--output", help="Output path")
    p.set_defaults(func=cmd_rotate)

    # flip
    p = subparsers.add_parser("flip", help="Flip image")
    p.add_argument("input", help="Image file")
    p.add_argument("--direction", "-d", required=True, help="Flip direction: h/horizontal or v/vertical")
    p.add_argument("-o", "--output", help="Output path")
    p.set_defaults(func=cmd_flip)
```

**Step 2: Test rotate and flip**

```bash
image-tools/skills/image/scripts/run.sh rotate /tmp/test_img.png --degrees 90 -o /tmp/test_rotated.png
image-tools/skills/image/scripts/run.sh flip /tmp/test_img.png --direction h -o /tmp/test_flipped.png

# Verify
image-tools/skills/image/scripts/venv/bin/python -c "
from PIL import Image
print('rotated:', Image.open('/tmp/test_rotated.png').size)
print('flipped:', Image.open('/tmp/test_flipped.png').size)
"
```

Expected: `rotated: (800, 1000)` (swapped dims), `flipped: (1000, 800)` (same dims).

**Step 3: Commit**

```bash
git add image-tools/skills/image/scripts/ops/transform.py
git commit -m "feat(image-tools): add rotate and flip operations"
```

---

### Task 9: Implement ops/analyze.py

**Files:**
- Create: `image-tools/skills/image/scripts/ops/analyze.py`

**Step 1: Create the module**

Provides `info` and `metadata` subcommands:

```python
"""Image analysis and metadata operations."""

import os
import json
from PIL import Image
from PIL.ExifTags import TAGS


def _collect_images(path):
    EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tiff", ".tif", ".gif"}
    if os.path.isdir(path):
        files = []
        for f in sorted(os.listdir(path)):
            if os.path.splitext(f)[1].lower() in EXTS:
                files.append(os.path.join(path, f))
        return files
    return [path]


def _get_info(filepath):
    """Get image info as dict."""
    img = Image.open(filepath)
    info = {
        "file": filepath,
        "format": img.format,
        "mode": img.mode,
        "width": img.size[0],
        "height": img.size[1],
        "size_bytes": os.path.getsize(filepath),
    }
    if img.mode == "RGBA":
        info["has_alpha"] = True
    if hasattr(img, "n_frames"):
        info["frames"] = img.n_frames
    return info


def cmd_info(args):
    """Show image information."""
    files = _collect_images(args.input)

    for filepath in files:
        info = _get_info(filepath)
        if args.json:
            print(json.dumps(info))
        else:
            print(f"File:   {info['file']}")
            print(f"Format: {info['format']}")
            print(f"Mode:   {info['mode']}")
            print(f"Size:   {info['width']}x{info['height']}")
            print(f"Bytes:  {info['size_bytes']:,}")
            if info.get("has_alpha"):
                print("Alpha:  yes")
            if info.get("frames"):
                print(f"Frames: {info['frames']}")
            if len(files) > 1:
                print("---")


def cmd_metadata(args):
    """Extract EXIF metadata."""
    files = _collect_images(args.input)
    all_metadata = []

    for filepath in files:
        img = Image.open(filepath)
        meta = {"file": filepath}
        exif_data = img.getexif()
        if exif_data:
            for tag_id, value in exif_data.items():
                tag_name = TAGS.get(tag_id, str(tag_id))
                # Convert bytes and other non-serializable types
                if isinstance(value, bytes):
                    value = value.hex()
                elif not isinstance(value, (str, int, float, bool, type(None))):
                    value = str(value)
                meta[tag_name] = value

        all_metadata.append(meta)

    if args.output:
        with open(args.output, "w") as f:
            json.dump(all_metadata, f, indent=2, default=str)
        print(f"Metadata for {len(files)} image(s) => {args.output}")
    else:
        print(json.dumps(all_metadata, indent=2, default=str))


def register(subparsers):
    # info
    p = subparsers.add_parser("info", help="Show image info")
    p.add_argument("input", help="Image file or directory")
    p.add_argument("--json", action="store_true", help="Output as JSON")
    p.set_defaults(func=cmd_info)

    # metadata
    p = subparsers.add_parser("metadata", help="Extract EXIF metadata")
    p.add_argument("input", help="Image file or directory")
    p.add_argument("-o", "--output", help="Save to JSON file")
    p.set_defaults(func=cmd_metadata)
```

**Step 2: Test info and metadata**

```bash
image-tools/skills/image/scripts/run.sh info /tmp/test_img.png
image-tools/skills/image/scripts/run.sh info /tmp/test_img.png --json
```

Expected: Displays file info (format, mode, size, bytes).

**Step 3: Commit**

```bash
git add image-tools/skills/image/scripts/ops/analyze.py
git commit -m "feat(image-tools): add info and metadata operations"
```

---

### Task 10: Create the SKILL.md

**Files:**
- Create: `image-tools/skills/image/SKILL.md`

**Step 1: Create SKILL.md**

```markdown
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
```

**Step 2: Commit**

```bash
git add image-tools/skills/image/SKILL.md
git commit -m "feat(image-tools): add skill definition"
```

---

### Task 11: Create instruction files

**Files:**
- Create: `image-tools/skills/image/instructions/resize-and-scale.md`
- Create: `image-tools/skills/image/instructions/crop-and-trim.md`
- Create: `image-tools/skills/image/instructions/convert-and-compress.md`
- Create: `image-tools/skills/image/instructions/alpha-and-composite.md`
- Create: `image-tools/skills/image/instructions/transform.md`
- Create: `image-tools/skills/image/instructions/analyze.md`

**Step 1: Create all six instruction files**

Each file documents the subcommands, flags, and examples for its operation category.

**resize-and-scale.md:**
````markdown
# Resize & Scale

## resize

Scale image to specific dimensions.

```bash
run.sh resize <input> [options]
```

| Flag | Description |
|------|-------------|
| `--width W` | Target width in pixels (maintains aspect ratio) |
| `--height H` | Target height in pixels (maintains aspect ratio) |
| `--width W --height H` | Exact dimensions (may stretch) |
| `--scale N` | Scale by percentage (50 = half size) |
| `-o PATH` | Output path (default: `<name>_WxH.<ext>`) |
| `--overwrite` | Overwrite input file |

**Examples:**
```bash
run.sh resize photo.png --width 800
run.sh resize photo.png --width 800 --height 600 -o resized.png
run.sh resize photo.png --scale 50
run.sh resize ./images/ --width 1200  # batch
```

## thumbnail

Generate thumbnail constrained to max size (preserves aspect ratio).

```bash
run.sh thumbnail <input> --size WxH [options]
```

| Flag | Description |
|------|-------------|
| `--size WxH` | Maximum bounding box (required) |
| `-o PATH` | Output path (default: `<name>_thumb.<ext>`) |

**Examples:**
```bash
run.sh thumbnail photo.png --size 200x200
run.sh thumbnail ./images/ --size 150x150  # batch
```
````

**crop-and-trim.md:**
````markdown
# Crop & Trim

## crop

Crop image by coordinates or center.

```bash
run.sh crop <input> [options]
```

| Flag | Description |
|------|-------------|
| `--box L,T,R,B` | Crop box: left, top, right, bottom in pixels |
| `--center WxH` | Center crop to WxH dimensions |
| `-o PATH` | Output path |

**Examples:**
```bash
run.sh crop photo.png --box 100,100,500,400
run.sh crop photo.png --center 500x500 -o square.png
```

## trim

Auto-trim uniform borders (whitespace, solid color).

```bash
run.sh trim <input> [options]
```

| Flag | Description |
|------|-------------|
| `--color R,G,B` | Background color to trim (default: sample corner pixel) |
| `-o PATH` | Output path |

**Examples:**
```bash
run.sh trim screenshot.png
run.sh trim icon.png --color "255,255,255" -o icon_trimmed.png
```

## pad

Pad image to target size with background color.

```bash
run.sh pad <input> --size WxH [options]
```

| Flag | Description |
|------|-------------|
| `--size WxH` | Target canvas size (required) |
| `--color R,G,B` | Padding color (default: 255,255,255 white) |
| `-o PATH` | Output path |

**Examples:**
```bash
run.sh pad logo.png --size 1000x1000 --color "0,0,0"
run.sh pad product.png --size 800x800
```
````

**convert-and-compress.md:**
````markdown
# Convert & Compress

## convert

Convert image to a different format.

```bash
run.sh convert <input> --format FMT [options]
```

| Flag | Description |
|------|-------------|
| `--format FMT` | Target format: png, jpg, webp, bmp, tiff, gif (required) |
| `--quality N` | Quality 1-100 (JPEG/WebP) or compression level (PNG) |
| `-o PATH` | Output path |

Batch: pass a directory to convert all images in it.

**Examples:**
```bash
run.sh convert photo.png --format webp --quality 80
run.sh convert ./images/ --format jpg --quality 90
run.sh convert icon.jpg --format png -o icon.png
```

**Notes:**
- JPEG cannot have alpha. RGBA images auto-convert to RGB.
- Shows file size change (bytes and percentage).

## compress

Reduce file size by recompressing at lower quality.

```bash
run.sh compress <input> [options]
```

| Flag | Description |
|------|-------------|
| `--quality N` | Quality 1-100 (default: 80) |
| `-o PATH` | Output path (default: `<name>_compressed.<ext>`) |

**Examples:**
```bash
run.sh compress photo.jpg --quality 60
run.sh compress ./images/ --quality 70  # batch
```
````

**alpha-and-composite.md:**
````markdown
# Alpha & Composite

## alpha

Manage alpha channel: add, remove, or make a color transparent.

```bash
run.sh alpha <input> [options]
```

| Flag | Description |
|------|-------------|
| `--add` | Add alpha channel (convert to RGBA) |
| `--remove` | Remove alpha (flatten to RGB) |
| `--background R,G,B` | Background color for --remove (default: white) |
| `--transparent R,G,B` | Make this color transparent |
| `--tolerance N` | Color match tolerance 0-255 (default: 0 exact) |
| `-o PATH` | Output path |

**Examples:**
```bash
run.sh alpha photo.png --add
run.sh alpha logo.png --transparent "255,255,255" --tolerance 20
run.sh alpha icon.png --remove --background "0,0,0" -o icon_flat.jpg
```

**Notes:**
- JPEG outputs from --transparent auto-save as PNG (JPEG has no alpha).
- Tolerance applies per-channel: each of R, G, B must be within N.

## composite

Overlay one image on another.

```bash
run.sh composite <base> <overlay> [options]
```

| Flag | Description |
|------|-------------|
| `--position POS` | Position: `center` or `X,Y` (default: center) |
| `--overlay-size WxH` | Resize overlay before compositing |
| `-o PATH` | Output path |

**Examples:**
```bash
run.sh composite photo.png watermark.png --position center
run.sh composite bg.png logo.png --position 10,10 --overlay-size 100x100 -o branded.png
```
````

**transform.md:**
````markdown
# Transform

## rotate

Rotate image by degrees (counter-clockwise).

```bash
run.sh rotate <input> --degrees N [options]
```

| Flag | Description |
|------|-------------|
| `--degrees N` | Rotation angle (required). Positive = CCW. |
| `--no-expand` | Keep original canvas size (clips corners) |
| `-o PATH` | Output path |

**Examples:**
```bash
run.sh rotate photo.png --degrees 90
run.sh rotate photo.png --degrees 45 -o angled.png
run.sh rotate photo.png --degrees 180 --no-expand
```

## flip

Flip image horizontally or vertically.

```bash
run.sh flip <input> --direction DIR [options]
```

| Flag | Description |
|------|-------------|
| `--direction DIR` | `h`/`horizontal` or `v`/`vertical` (required) |
| `-o PATH` | Output path |

**Examples:**
```bash
run.sh flip photo.png --direction h
run.sh flip photo.png --direction vertical -o flipped.png
```
````

**analyze.md:**
````markdown
# Analyze

## info

Display image information: format, mode, dimensions, file size.

```bash
run.sh info <input> [options]
```

| Flag | Description |
|------|-------------|
| `--json` | Output as JSON (one object per line) |

Batch: pass a directory to show info for all images.

**Examples:**
```bash
run.sh info photo.png
run.sh info photo.png --json
run.sh info ./images/  # batch
```

## metadata

Extract EXIF metadata from images.

```bash
run.sh metadata <input> [options]
```

| Flag | Description |
|------|-------------|
| `-o PATH` | Save metadata to JSON file |

Batch: pass a directory to extract metadata from all images.

**Examples:**
```bash
run.sh metadata photo.jpg
run.sh metadata ./photos/ -o metadata_report.json
```

**Notes:**
- Not all images have EXIF (PNG/WebP usually don't, JPEG/TIFF do).
- Bytes values are hex-encoded in JSON output.
```
````

**Step 2: Commit**

```bash
git add image-tools/skills/image/instructions/
git commit -m "feat(image-tools): add instruction files for all operations"
```

---

### Task 12: End-to-end test and validate

**Step 1: Run full JSON validation**

```bash
jq . image-tools/.claude-plugin/plugin.json
jq . .claude-plugin/marketplace.json
```

Expected: Valid JSON, no errors.

**Step 2: Run marketplace consistency check**

```bash
dir="image-tools"
plugin_name=$(jq -r '.name' "$dir/.claude-plugin/plugin.json")
plugin_v=$(jq -r '.version' "$dir/.claude-plugin/plugin.json")
market_name=$(jq -r ".plugins[] | select(.source == \"./$dir\") | .name" .claude-plugin/marketplace.json)
market_v=$(jq -r ".plugins[] | select(.name == \"$plugin_name\") | .version" .claude-plugin/marketplace.json)

echo "Directory: $dir"
echo "plugin.json name: $plugin_name, version: $plugin_v"
echo "marketplace name: $market_name, version: $market_v"

[ "$plugin_name" = "$dir" ] && echo "OK: name matches directory" || echo "ERROR: name mismatch"
[ "$plugin_name" = "$market_name" ] && echo "OK: names match" || echo "ERROR: name mismatch"
[ "$plugin_v" = "$market_v" ] && echo "OK: versions match" || echo "ERROR: version mismatch"
```

Expected: All OK.

**Step 3: Check scripts are executable**

```bash
find image-tools -name "*.sh" ! -perm -111 -print
```

Expected: No output (all .sh files executable).

**Step 4: Run check-setup.sh**

```bash
bash image-tools/skills/image/scripts/check-setup.sh
```

Expected: All checks pass, outputs `{"status": "ok"}`

**Step 5: Run full CLI help**

```bash
image-tools/skills/image/scripts/run.sh --help
```

Expected: Shows all 13 subcommands.

**Step 6: Run each subcommand end-to-end**

```bash
S="image-tools/skills/image/scripts/run.sh"

# Create test image
image-tools/skills/image/scripts/venv/bin/python -c "
from PIL import Image
Image.new('RGB', (1000, 800), 'blue').save('/tmp/it_test.png')
Image.new('RGBA', (100, 100), (255, 0, 0, 128)).save('/tmp/it_overlay.png')
"

$S resize /tmp/it_test.png --width 500 -o /tmp/it_resized.png
$S thumbnail /tmp/it_test.png --size 200x200 -o /tmp/it_thumb.png
$S crop /tmp/it_test.png --center 400x400 -o /tmp/it_cropped.png
$S trim /tmp/it_test.png -o /tmp/it_trimmed.png
$S pad /tmp/it_test.png --size 1200x1200 -o /tmp/it_padded.png
$S convert /tmp/it_test.png --format webp -o /tmp/it_converted.webp
$S compress /tmp/it_test.png --quality 60 -o /tmp/it_compressed.png
$S alpha /tmp/it_test.png --add -o /tmp/it_alpha.png
$S rotate /tmp/it_test.png --degrees 90 -o /tmp/it_rotated.png
$S flip /tmp/it_test.png --direction h -o /tmp/it_flipped.png
$S info /tmp/it_test.png
$S metadata /tmp/it_test.png
$S composite /tmp/it_test.png /tmp/it_overlay.png -o /tmp/it_composite.png

echo "=== All commands completed ==="
```

Expected: All commands run without errors.

**Step 7: Commit any fixes if needed**

If any test reveals issues, fix the relevant ops module and commit the fix.

---

### Task 13: Update repo-map and final commit

**Files:**
- Modify: `my-plugin-dev/skills/dev/reference/repo-map.md` (regenerate)

**Step 1: Regenerate repo-map.md**

Scan the filesystem and rebuild the entire repo-map.md to include the new `image-tools` plugin with all its components.

**Step 2: Final commit**

```bash
git add my-plugin-dev/skills/dev/reference/repo-map.md
git commit -m "docs(my-plugin-dev): update repo-map with image-tools plugin"
```
