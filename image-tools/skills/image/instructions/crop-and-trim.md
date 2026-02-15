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
