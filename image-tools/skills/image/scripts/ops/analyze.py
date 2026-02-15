"""Image analysis and metadata operations."""

import os
import json
from PIL import Image
from PIL.ExifTags import TAGS


def _collect_images(path):
    EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tiff", ".tif", ".gif"}
    if os.path.isdir(path):
        files = []
        for f in sorted(os.listdir(path)):
            if os.path.splitext(f)[1].lower() in EXTS:
                files.append(os.path.join(path, f))
        return files
    return [path]


def _get_info(filepath):
    """Get image info as dict."""
    img = Image.open(filepath)
    info = {
        "file": filepath,
        "format": img.format,
        "mode": img.mode,
        "width": img.size[0],
        "height": img.size[1],
        "size_bytes": os.path.getsize(filepath),
    }
    if img.mode == "RGBA":
        info["has_alpha"] = True
    if hasattr(img, "n_frames"):
        info["frames"] = img.n_frames
    return info


def cmd_info(args):
    """Show image information."""
    files = _collect_images(args.input)

    for filepath in files:
        info = _get_info(filepath)
        if args.json:
            print(json.dumps(info))
        else:
            print(f"File:   {info['file']}")
            print(f"Format: {info['format']}")
            print(f"Mode:   {info['mode']}")
            print(f"Size:   {info['width']}x{info['height']}")
            print(f"Bytes:  {info['size_bytes']:,}")
            if info.get("has_alpha"):
                print("Alpha:  yes")
            if info.get("frames"):
                print(f"Frames: {info['frames']}")
            if len(files) > 1:
                print("---")


def cmd_metadata(args):
    """Extract EXIF metadata."""
    files = _collect_images(args.input)
    all_metadata = []

    for filepath in files:
        img = Image.open(filepath)
        meta = {"file": filepath}
        exif_data = img.getexif()
        if exif_data:
            for tag_id, value in exif_data.items():
                tag_name = TAGS.get(tag_id, str(tag_id))
                if isinstance(value, bytes):
                    value = value.hex()
                elif not isinstance(value, (str, int, float, bool, type(None))):
                    value = str(value)
                meta[tag_name] = value

        all_metadata.append(meta)

    if args.output:
        with open(args.output, "w") as f:
            json.dump(all_metadata, f, indent=2, default=str)
        print(f"Metadata for {len(files)} image(s) => {args.output}")
    else:
        print(json.dumps(all_metadata, indent=2, default=str))


def register(subparsers):
    p = subparsers.add_parser("info", help="Show image info")
    p.add_argument("input", help="Image file or directory")
    p.add_argument("--json", action="store_true", help="Output as JSON")
    p.set_defaults(func=cmd_info)

    p = subparsers.add_parser("metadata", help="Extract EXIF metadata")
    p.add_argument("input", help="Image file or directory")
    p.add_argument("-o", "--output", help="Save to JSON file")
    p.set_defaults(func=cmd_metadata)
