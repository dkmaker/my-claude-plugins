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
