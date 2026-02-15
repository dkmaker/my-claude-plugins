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
