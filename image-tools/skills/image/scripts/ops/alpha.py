"""Alpha channel and compositing operations."""

import os
import colorsys
from PIL import Image, ImageFilter

try:
    import numpy as np
    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False


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


def _rgb_to_hue(r, g, b):
    """Convert RGB (0-255) to hue (0-360)."""
    h, _, _ = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    return h * 360.0


def _chroma_key_numpy(img, target, tolerance, feather):
    """HSV-based chroma key with spill suppression using numpy."""
    arr = np.array(img, dtype=np.float64)
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]

    # Convert target to HSV hue
    target_h = _rgb_to_hue(*target)
    target_s_min = 0.15  # minimum saturation to be considered chromatic

    # Convert image to HSV
    # Normalize to 0-1
    rn, gn, bn = r / 255.0, g / 255.0, b / 255.0
    cmax = np.maximum(np.maximum(rn, gn), bn)
    cmin = np.minimum(np.minimum(rn, gn), bn)
    delta = cmax - cmin

    # Hue calculation
    hue = np.zeros_like(delta)
    mask_r = (cmax == rn) & (delta > 0)
    mask_g = (cmax == gn) & (delta > 0)
    mask_b = (cmax == bn) & (delta > 0)
    hue[mask_r] = 60.0 * (((gn[mask_r] - bn[mask_r]) / delta[mask_r]) % 6)
    hue[mask_g] = 60.0 * (((bn[mask_g] - rn[mask_g]) / delta[mask_g]) + 2)
    hue[mask_b] = 60.0 * (((rn[mask_b] - gn[mask_b]) / delta[mask_b]) + 4)

    # Saturation (suppress divide-by-zero for black pixels)
    with np.errstate(invalid='ignore'):
        sat = np.where(cmax > 0, delta / cmax, 0)

    # Hue distance (circular)
    hue_diff = np.abs(hue - target_h)
    hue_diff = np.minimum(hue_diff, 360.0 - hue_diff)

    # Background detection: match hue within tolerance, with minimum saturation
    hue_tolerance = max(tolerance, 15)
    hue_feather = max(feather, 20)

    is_chromatic = sat > target_s_min
    bg_core = is_chromatic & (hue_diff <= hue_tolerance)
    bg_edge = is_chromatic & (hue_diff > hue_tolerance) & (hue_diff <= hue_tolerance + hue_feather)

    # Alpha: 0 for background, gradient for edges, 255 for subject
    alpha = np.full(r.shape, 255.0)
    alpha[bg_core] = 0.0
    edge_alpha = (hue_diff[bg_edge] - hue_tolerance) / hue_feather * 255.0
    alpha[bg_edge] = edge_alpha

    # Also catch low-saturation near-white/near-black pixels that are close to target in RGB
    rgb_dist = np.sqrt((r - target[0])**2 + (g - target[1])**2 + (b - target[2])**2)
    rgb_close = rgb_dist < (tolerance * 5)
    alpha[rgb_close & ~is_chromatic] = 0.0

    # Gaussian blur the alpha mask for smooth antialiased edges
    blur_radius = max(1.0, feather / 15.0)
    alpha_img = Image.fromarray(alpha.astype(np.uint8), mode='L')
    alpha_img = alpha_img.filter(ImageFilter.GaussianBlur(radius=blur_radius))
    alpha = np.array(alpha_img, dtype=np.float64)

    # Spill suppression: remove background color from edge/subject pixels
    # For magenta (high R, high B, low G): clamp R and B so they don't
    # exceed what's natural. Use the "low channel" as reference.
    # Identify which channel is the "low" one in the target
    t_channels = list(target)
    low_idx = t_channels.index(min(t_channels))
    high_indices = [i for i in range(3) if i != low_idx]

    # Spill strength based on proximity to background
    # Pixels closer to bg get more despill
    max_rgb_dist = np.sqrt(3 * 255**2)
    spill_strength = np.clip(1.0 - (rgb_dist / (max_rgb_dist * 0.3)), 0, 1)
    # Only despill pixels that are partially or fully opaque and near edges
    needs_despill = (alpha > 0) & (spill_strength > 0)

    channels = [r.copy(), g.copy(), b.copy()]
    low_channel = channels[low_idx]

    for hi in high_indices:
        # Clamp high channels: they shouldn't exceed low_channel + natural_offset
        # The offset accounts for natural color (e.g., a red object has high R legitimately)
        # Use a gentle clamp: blend toward the low channel value
        excess = np.maximum(0, channels[hi] - low_channel - 30)
        reduction = excess * spill_strength * 0.6
        channels[hi] = np.where(needs_despill, channels[hi] - reduction, channels[hi])

    channels = [np.clip(c, 0, 255) for c in channels]

    # Build output
    out_arr = np.stack([
        channels[0].astype(np.uint8),
        channels[1].astype(np.uint8),
        channels[2].astype(np.uint8),
        alpha.astype(np.uint8),
    ], axis=-1)

    result = Image.fromarray(out_arr, mode='RGBA')
    transparent_count = int(np.sum(alpha < 255))
    return result, transparent_count


def _chroma_key_fallback(img, target, tolerance, feather):
    """Simple RGB fallback when numpy is not available."""
    img = img.convert("RGBA")
    data = img.getdata()
    new_data = []
    count = 0
    for pixel in data:
        r, g, b = pixel[:3]
        max_diff = max(abs(r - target[0]), abs(g - target[1]), abs(b - target[2]))
        if max_diff <= tolerance:
            new_data.append((0, 0, 0, 0))
            count += 1
        elif feather > 0 and max_diff <= tolerance + feather:
            alpha = int(255 * (max_diff - tolerance) / feather)
            new_data.append((r, g, b, alpha))
            count += 1
        else:
            new_data.append(pixel)
    img.putdata(new_data)
    return img, count


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

        if HAS_NUMPY and feather > 0:
            result, count = _chroma_key_numpy(img, target, tolerance, feather)
        else:
            if not HAS_NUMPY and feather > 0:
                print("Warning: numpy not available, using basic RGB matching (no spill suppression)")
            result, count = _chroma_key_fallback(img, target, tolerance, feather)

        out = _output_path(args.input, "transparent", args.output)
        result.save(out)
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
