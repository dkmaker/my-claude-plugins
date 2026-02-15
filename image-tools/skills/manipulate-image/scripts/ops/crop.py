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
        bg_color = img.getpixel((0, 0))

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

    x = (target_w - img.size[0]) // 2
    y = (target_h - img.size[1]) // 2
    result.paste(img, (x, y))

    out = _output_path(args.input, "padded", args.output)
    result.save(out)
    print(f"{args.input}: {img.size[0]}x{img.size[1]} -> {target_w}x{target_h} => {out}")


def register(subparsers):
    p = subparsers.add_parser("crop", help="Crop image")
    p.add_argument("input", help="Image file")
    p.add_argument("-o", "--output", help="Output path")
    p.add_argument("--box", help="Crop box as left,top,right,bottom")
    p.add_argument("--center", help="Center crop as WxH")
    p.set_defaults(func=cmd_crop)

    p = subparsers.add_parser("trim", help="Auto-trim borders")
    p.add_argument("input", help="Image file")
    p.add_argument("-o", "--output", help="Output path")
    p.add_argument("--color", help="Background color to trim as R,G,B (default: sample corner)")
    p.set_defaults(func=cmd_trim)

    p = subparsers.add_parser("pad", help="Pad image to target size")
    p.add_argument("input", help="Image file")
    p.add_argument("--size", required=True, help="Target size as WxH")
    p.add_argument("--color", help="Padding color as R,G,B (default: 255,255,255)")
    p.add_argument("-o", "--output", help="Output path")
    p.set_defaults(func=cmd_pad)
