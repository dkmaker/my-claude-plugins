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
