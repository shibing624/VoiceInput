#!/usr/bin/env python3
"""Generate Assets/AppIcon.icns for VoiceInput.

Draws a deep-indigo rounded-square icon with a white microphone.
Requires Pillow (auto-installed if missing).
"""
import os, sys, subprocess, shutil
from pathlib import Path

ICONSET_SIZES: dict[str, int] = {
    "icon_16x16.png":      16,
    "icon_16x16@2x.png":   32,
    "icon_32x32.png":      32,
    "icon_32x32@2x.png":   64,
    "icon_128x128.png":   128,
    "icon_128x128@2x.png":256,
    "icon_256x256.png":   256,
    "icon_256x256@2x.png":512,
    "icon_512x512.png":   512,
    "icon_512x512@2x.png":1024,
}

ROOT      = Path(__file__).parent.parent
ICONSET   = ROOT / "Assets" / "AppIcon.iconset"
ICNS_OUT  = ROOT / "Assets" / "AppIcon.icns"


def ensure_pillow():
    try:
        from PIL import Image, ImageDraw
        return Image, ImageDraw
    except ImportError:
        print("[icon] Pillow not found, installing...", flush=True)
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "--quiet", "Pillow"],
            check=True,
        )
        from PIL import Image, ImageDraw
        return Image, ImageDraw


def draw_icon(size: int, Image, ImageDraw):
    """Draw a 'size × size' microphone icon, returning an RGBA Image."""
    s = size
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d   = ImageDraw.Draw(img)

    # ── Background: deep indigo rounded square ─────────────────────────
    radius = int(s * 0.225)            # macOS-style corner rounding
    bg_color = (30, 32, 58, 255)       # #1E203A deep indigo
    d.rounded_rectangle([0, 0, s - 1, s - 1], radius=radius, fill=bg_color)

    # Subtle top-half highlight for depth
    hi = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    hi_d = ImageDraw.Draw(hi)
    hi_d.rounded_rectangle([0, 0, s - 1, s // 2], radius=radius,
                            fill=(255, 255, 255, 18))
    img = Image.alpha_composite(img, hi)
    d = ImageDraw.Draw(img)

    # ── Microphone icon (white) ────────────────────────────────────────
    white = (255, 255, 255, 255)
    lw    = max(2, int(s * 0.033))     # stroke width for arc / stem / base

    # Capsule (rounded rectangle, fully-pill shaped)
    cw = s * 0.22
    ch = s * 0.30
    cy = s * 0.20
    cx = (s - cw) / 2
    d.rounded_rectangle([cx, cy, cx + cw, cy + ch], radius=cw / 2, fill=white)

    # Stand arc – U-shape wrapping below the capsule
    # Arc center sits 82 % down the capsule so it overlaps the bottom edge.
    ar  = s * 0.21          # radius of the arc
    acx = s / 2
    acy = cy + ch * 0.82
    bb  = [acx - ar, acy - ar, acx + ar, acy + ar]
    # In Pillow (screen coords, Y-down): start=0→end=180 draws the
    # bottom semicircle → U-shape that opens upward, hugging the capsule.
    d.arc(bb, start=0, end=180, fill=white, width=lw)

    # Stem
    stem_y1 = acy + ar
    stem_y2 = stem_y1 + s * 0.08
    d.line([(s / 2, stem_y1), (s / 2, stem_y2)], fill=white, width=lw)

    # Base (horizontal bar)
    bw = ar * 0.72
    d.line(
        [(s / 2 - bw / 2, stem_y2), (s / 2 + bw / 2, stem_y2)],
        fill=white, width=lw,
    )

    return img


def main() -> None:
    Image, ImageDraw = ensure_pillow()

    ICONSET.mkdir(parents=True, exist_ok=True)
    ICNS_OUT.parent.mkdir(parents=True, exist_ok=True)

    print("[icon] Rendering icon...", flush=True)
    master = draw_icon(1024, Image, ImageDraw)

    for name, px in ICONSET_SIZES.items():
        resized = master.resize((px, px), Image.LANCZOS)
        resized.save(ICONSET / name)
        print(f"  {name} ({px}px)", flush=True)

    print("[icon] Running iconutil...", flush=True)
    subprocess.run(
        ["iconutil", "-c", "icns", str(ICONSET), "-o", str(ICNS_OUT)],
        check=True,
    )
    print(f"[icon] ✓ {ICNS_OUT}", flush=True)


if __name__ == "__main__":
    main()
