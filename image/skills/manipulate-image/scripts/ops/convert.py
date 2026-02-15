"""Format conversion and compression operations."""

import os
from PIL import Image


def _collect_images(path):
    EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tiff", ".tif", ".gif"}
    if os.path.isdir(path):
        files = []
        for f in sorted(os.listdir(path)):
            if os.path.splitext(f)[1].lower() in EXTS:
                files.append(os.path.join(path, f))
        return files
    return [path]


FORMAT_MAP = {
    "png": "PNG",
    "jpg": "JPEG",
    "jpeg": "JPEG",
    "webp": "WEBP",
    "bmp": "BMP",
    "tiff": "TIFF",
    "gif": "GIF",
}


def cmd_convert(args):
    """Convert image(s) to a different format."""
    files = _collect_images(args.input)
    fmt = args.format.lower()
    pil_format = FORMAT_MAP.get(fmt)
    if not pil_format:
        print(f"Error: unsupported format '{fmt}'. Supported: {', '.join(FORMAT_MAP.keys())}")
        return

    save_kwargs = {}
    if args.quality and pil_format in ("JPEG", "WEBP"):
        save_kwargs["quality"] = args.quality
    if pil_format == "PNG" and args.quality:
        save_kwargs["compress_level"] = min(9, max(0, (100 - args.quality) // 10))

    for filepath in files:
        img = Image.open(filepath)

        if pil_format == "JPEG" and img.mode in ("RGBA", "P", "LA"):
            img = img.convert("RGB")

        base = os.path.splitext(filepath)[0]
        out = args.output if (args.output and len(files) == 1) else f"{base}.{fmt}"
        os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
        img.save(out, pil_format, **save_kwargs)

        orig_size = os.path.getsize(filepath)
        new_size = os.path.getsize(out)
        ratio = ((orig_size - new_size) / orig_size) * 100 if orig_size > 0 else 0
        print(f"{filepath} -> {out} ({orig_size:,}B -> {new_size:,}B, {ratio:+.1f}%)")


def cmd_compress(args):
    """Compress image by adjusting quality."""
    files = _collect_images(args.input)
    quality = args.quality or 80

    for filepath in files:
        img = Image.open(filepath)
        ext = os.path.splitext(filepath)[1].lower()
        pil_format = FORMAT_MAP.get(ext.lstrip("."), "PNG")

        if pil_format == "JPEG" and img.mode in ("RGBA", "P", "LA"):
            img = img.convert("RGB")

        base, orig_ext = os.path.splitext(filepath)
        out = args.output if (args.output and len(files) == 1) else f"{base}_compressed{orig_ext}"

        save_kwargs = {}
        if pil_format in ("JPEG", "WEBP"):
            save_kwargs["quality"] = quality
            save_kwargs["optimize"] = True
        elif pil_format == "PNG":
            save_kwargs["optimize"] = True

        img.save(out, pil_format, **save_kwargs)

        orig_size = os.path.getsize(filepath)
        new_size = os.path.getsize(out)
        ratio = ((orig_size - new_size) / orig_size) * 100 if orig_size > 0 else 0
        print(f"{filepath} -> {out} ({orig_size:,}B -> {new_size:,}B, {ratio:+.1f}%)")


def register(subparsers):
    p = subparsers.add_parser("convert", help="Convert image format")
    p.add_argument("input", help="Image file or directory")
    p.add_argument("--format", "-f", required=True, help="Target format: png, jpg, webp, bmp, tiff, gif")
    p.add_argument("--quality", "-q", type=int, help="Quality 1-100 (for JPEG/WebP)")
    p.add_argument("-o", "--output", help="Output path")
    p.set_defaults(func=cmd_convert)

    p = subparsers.add_parser("compress", help="Compress image")
    p.add_argument("input", help="Image file or directory")
    p.add_argument("--quality", "-q", type=int, default=80, help="Quality 1-100 (default: 80)")
    p.add_argument("-o", "--output", help="Output path")
    p.set_defaults(func=cmd_compress)
