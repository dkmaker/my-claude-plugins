"""Alpha channel and compositing operations."""

import os
from PIL import Image


def _output_path(input_path, suffix, output=None):
    if output:
        return output
    base, ext = os.path.splitext(input_path)
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
        feather = args.feather or 0
        img = img.convert("RGBA")
        data = img.getdata()
        new_data = []
        count = 0
        for pixel in data:
            r, g, b = pixel[:3]
            dr, dg, db = abs(r - target[0]), abs(g - target[1]), abs(b - target[2])
            max_diff = max(dr, dg, db)
            if max_diff <= tolerance:
                # Exact match zone — fully transparent
                new_data.append((0, 0, 0, 0))
                count += 1
            elif feather > 0 and max_diff <= tolerance + feather:
                # Feather zone — proportional alpha for smooth edges
                alpha = int(255 * (max_diff - tolerance) / feather)
                # Decontaminate RGB: remove background color contribution
                # The pixel is a mix: pixel = subject * t + bg * (1-t), where t = alpha/255
                # Solve for subject: subject = (pixel - bg * (1-t)) / t
                t = alpha / 255.0
                if t > 0.01:
                    cr = min(255, max(0, int((r - target[0] * (1 - t)) / t)))
                    cg = min(255, max(0, int((g - target[1] * (1 - t)) / t)))
                    cb = min(255, max(0, int((b - target[2] * (1 - t)) / t)))
                else:
                    cr, cg, cb = 0, 0, 0
                new_data.append((cr, cg, cb, alpha))
                count += 1
            else:
                new_data.append(pixel)
        img.putdata(new_data)
        out = _output_path(args.input, "transparent", args.output)
        img.save(out)
        print(f"{args.input}: made {count} pixels transparent/semi-transparent => {out}")

    else:
        print("Error: specify --add, --remove, or --transparent R,G,B")


def cmd_composite(args):
    """Overlay one image on another."""
    base = Image.open(args.base).convert("RGBA")
    overlay = Image.open(args.overlay).convert("RGBA")

    if args.position == "center":
        x = (base.size[0] - overlay.size[0]) // 2
        y = (base.size[1] - overlay.size[1]) // 2
    elif args.position:
        parts = args.position.split(",")
        x, y = int(parts[0]), int(parts[1])
    else:
        x, y = 0, 0

    if args.overlay_size:
        ow, oh = [int(x) for x in args.overlay_size.lower().split("x")]
        overlay = overlay.resize((ow, oh), Image.LANCZOS)

    result = base.copy()
    result.paste(overlay, (x, y), overlay)

    out = args.output or _output_path(args.base, "composite")
    result.save(out)
    print(f"Composited {args.overlay} onto {args.base} at ({x},{y}) => {out}")


def register(subparsers):
    p = subparsers.add_parser("alpha", help="Manage alpha channel")
    p.add_argument("input", help="Image file")
    p.add_argument("-o", "--output", help="Output path")
    p.add_argument("--add", action="store_true", help="Add alpha channel")
    p.add_argument("--remove", action="store_true", help="Remove alpha (flatten)")
    p.add_argument("--background", help="Background color for --remove as R,G,B (default: white)")
    p.add_argument("--transparent", help="Make color transparent as R,G,B")
    p.add_argument("--tolerance", type=int, default=0, help="Color match tolerance (0-255)")
    p.add_argument("--feather", type=int, default=0, help="Feather radius for antialiased edges (0-255, default: 0)")
    p.set_defaults(func=cmd_alpha)

    p = subparsers.add_parser("composite", help="Overlay images")
    p.add_argument("base", help="Base image file")
    p.add_argument("overlay", help="Overlay image file")
    p.add_argument("-o", "--output", help="Output path")
    p.add_argument("--position", default="center", help="Position: center or X,Y")
    p.add_argument("--overlay-size", help="Resize overlay to WxH before compositing")
    p.set_defaults(func=cmd_composite)
