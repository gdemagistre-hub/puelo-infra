#!/usr/bin/env python3
"""Genera ic_launcher Android e iOS AppIcon desde el icono P de Play."""
from __future__ import annotations

import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.stderr.write("Pillow no esta instalado. pip install pillow\n")
    sys.exit(1)

ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

CANDIDATES = (
    os.path.join("assets", "brand", "app_icon_1024.png"),
    os.path.join("assets", "images", "app_icon_1024.png"),
    os.path.join("assets", "images", "play_icon_512.png"),
    os.path.join("brand_prox", "android_launcher", "app_icon_1024.png"),
    os.path.join("brand_prox", "android_launcher", "play_icon_512.png"),
)


def _find_master(root: str) -> str:
    for rel in CANDIDATES:
        path = os.path.join(root, rel)
        if os.path.isfile(path):
            return path
    sys.stderr.write(
        "Falta el icono P 1024/512. Copia el de Play a\n"
        "  assets/brand/app_icon_1024.png\n"
    )
    sys.exit(1)


def _square(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    w, h = im.size
    if w == h:
        return im
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    return im.crop((left, top, left + side, top + side))


def apply_ios(root: str, master: Image.Image) -> int:
    icon_dir = os.path.join(
        root, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
    )
    if not os.path.isdir(icon_dir):
        return 0
    n = 0
    rgb = Image.new("RGB", master.size, (255, 255, 255))
    rgb.paste(master, mask=master.split()[-1] if master.mode == "RGBA" else None)
    for name in os.listdir(icon_dir):
        if not name.lower().endswith(".png"):
            continue
        path = os.path.join(icon_dir, name)
        try:
            existing = Image.open(path)
            w, h = existing.size
        except Exception:
            w = h = 1024
        rgb.resize((w, h), Image.Resampling.LANCZOS).save(path, "PNG", optimize=True)
        n += 1
    rgb.resize((1024, 1024), Image.Resampling.LANCZOS).save(
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
    rgb = Image.new("RGB", master.size, (255, 255, 255))
    rgb.paste(master, mask=master.split()[-1] if master.mode == "RGBA" else None)
    for folder, px in ANDROID_SIZES.items():
        dest_dir = os.path.join(res, folder)
        os.makedirs(dest_dir, exist_ok=True)
        img = rgb.resize((px, px), Image.Resampling.LANCZOS)
        for fname in ("ic_launcher.png", "ic_launcher_round.png"):
            img.save(os.path.join(dest_dir, fname), "PNG", optimize=True)
            n += 1
    return n


def main() -> int:
    here = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    src = _find_master(here)
    master = _square(Image.open(src))
    brand = os.path.join(here, "assets", "brand")
    os.makedirs(brand, exist_ok=True)
    out = os.path.join(brand, "app_icon_1024.png")
    master.resize((1024, 1024), Image.Resampling.LANCZOS).save(out, "PNG", optimize=True)
    ios_n = apply_ios(here, master)
    and_n = apply_android(here, master)
    print(f"PROX P icon from {src} ios={ios_n} android={and_n}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
