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
    print(f"{args.input}: rotated {args.degrees} degrees => {out} ({result.size[0]}x{result.size[1]})")


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
    p = subparsers.add_parser("rotate", help="Rotate image")
    p.add_argument("input", help="Image file")
    p.add_argument("--degrees", "-d", type=float, required=True, help="Rotation angle in degrees (CCW)")
    p.add_argument("--no-expand", action="store_true", help="Don't expand canvas to fit rotated image")
    p.add_argument("-o", "--output", help="Output path")
    p.set_defaults(func=cmd_rotate)

    p = subparsers.add_parser("flip", help="Flip image")
    p.add_argument("input", help="Image file")
    p.add_argument("--direction", "-d", required=True, help="Flip direction: h/horizontal or v/vertical")
    p.add_argument("-o", "--output", help="Output path")
    p.set_defaults(func=cmd_flip)
