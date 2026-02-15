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
