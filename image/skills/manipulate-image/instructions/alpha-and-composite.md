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
| `--feather N` | Feather radius for antialiased edges 0-255 (default: 0) |
| `-o PATH` | Output path |

**Examples:**
```bash
run.sh alpha photo.png --add
run.sh alpha logo.png --transparent "255,255,255" --tolerance 20
run.sh alpha logo.png --transparent "255,255,255" --tolerance 10 --feather 30
run.sh alpha icon.png --remove --background "0,0,0" -o icon_flat.jpg
```

**Notes:**
- JPEG outputs from --transparent auto-save as PNG (JPEG has no alpha).
- **With `--feather`** (recommended): Uses HSV color space detection + Gaussian blur antialiasing + spill suppression. Detects background by hue (handles imprecise AI-generated colors), blurs the alpha mask for smooth edges, and removes background color contamination from outline pixels.
- **Without `--feather`**: Uses simple RGB tolerance matching (binary transparency). Fast but produces hard edges and color fringe.
- For AI-generated chroma key backgrounds: use `--tolerance 15 --feather 40`.
- Requires numpy for the HSV/spill pipeline (falls back to basic RGB if numpy is missing).

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
