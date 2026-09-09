#!/usr/bin/env python3
"""Genera el icono PROX (casita + pin) para iOS AppIcon y Android mipmap."""
from __future__ import annotations

import os
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.stderr.write("Pillow no esta instalado. pip install pillow\n")
    sys.exit(1)

TEAL = (0, 163, 176)
WHITE = (255, 255, 255)

ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def draw_icon(size: int, bg=WHITE, color=TEAL) -> Image.Image:
    im = Image.new("RGB", (size, size), bg)
    d = ImageDraw.Draw(im)
    cx = cy = size / 2.0
    s = size * 0.70
    mw, mh = s, s * 0.88
    left = cx - mw / 2.0
    top = cy - mh / 2.0
    stroke = s * 0.165

    def P(x: float, y: float):
        return (left + mw * x / 100.0, top + mh * y / 88.0)

    def cap(pt, w):
        r = w / 2.0
        d.ellipse([pt[0] - r, pt[1] - r, pt[0] + r, pt[1] + r], fill=color)

    def thick(a, b, w):
        d.line([a, b], fill=color, width=max(1, int(round(w))))
        cap(a, w)
        cap(b, w)

    peak = P(50, 7)
    eave_l = P(11, 37)
    eave_r = P(89, 37)
    foot_l = P(11, 81)
    foot_r = P(89, 81)
    thick(foot_l, eave_l, stroke)
    thick(eave_l, peak, stroke)
    thick(peak, eave_r, stroke)
    thick(eave_r, foot_r, stroke)

    pin_cx, pin_cy = P(50, 51.5)
    pin_r = mw * 0.148
    d.ellipse(
        [
            pin_cx - pin_r,
            pin_cy - pin_r * 1.02,
            pin_cx + pin_r,
            pin_cy + pin_r * 0.82,
        ],
        fill=color,
    )
    d.polygon(
        [
            (pin_cx - pin_r * 0.90, pin_cy + pin_r * 0.22),
            (pin_cx + pin_r * 0.90, pin_cy + pin_r * 0.22),
            (pin_cx, pin_cy + pin_r * 1.70),
        ],
        fill=color,
    )
    hr = pin_r * 0.38
    d.ellipse(
        [pin_cx - hr, pin_cy - hr * 0.90, pin_cx + hr, pin_cy + hr * 0.90],
        fill=bg,
    )
    return im


def apply_ios(root: str, master: Image.Image) -> int:
    icon_dir = os.path.join(
        root, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
    )
    if not os.path.isdir(icon_dir):
        return 0
    n = 0
    for name in os.listdir(icon_dir):
        if not name.lower().endswith(".png"):
            continue
        path = os.path.join(icon_dir, name)
        try:
            existing = Image.open(path)
            w, h = existing.size
        except Exception:
            w = h = 1024
        master.resize((w, h), Image.Resampling.LANCZOS).save(
            path, "PNG", optimize=True
        )
        n += 1
    master.save(
        os.path.join(icon_dir, "Icon-App-1024x1024@1x.png"),
        "PNG",
        optimize=True,
    )
    return max(n, 1)


def apply_android(root: str, master: Image.Image) -> int:
    res = os.path.join(root, "android", "app", "src", "main", "res")
    if not os.path.isdir(res):
        return 0
    n = 0
    for folder, px in ANDROID_SIZES.items():
        dest_dir = os.path.join(res, folder)
        os.makedirs(dest_dir, exist_ok=True)
        img = master.resize((px, px), Image.Resampling.LANCZOS)
        for fname in ("ic_launcher.png", "ic_launcher_round.png"):
            img.save(os.path.join(dest_dir, fname), "PNG", optimize=True)
            n += 1
    return n


def main() -> int:
    here = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    master = draw_icon(1024)
    brand = os.path.join(here, "assets", "brand")
    os.makedirs(brand, exist_ok=True)
    master_path = os.path.join(brand, "app_icon_ios_1024.png")
    master.save(master_path, "PNG", optimize=True)
    ios_n = apply_ios(here, master)
    and_n = apply_android(here, master)
    print(f"PROX house+pin escrito {master_path} ios={ios_n} android={and_n}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
