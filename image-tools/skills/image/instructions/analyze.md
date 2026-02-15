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
