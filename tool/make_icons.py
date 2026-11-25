#!/usr/bin/env python3
"""Generate the NightsunTV launcher, adaptive, monochrome and splash icons.

The mark is drawn procedurally at 4x supersampling so it stays crisp at every
launcher size: a warm sun with a play cut-out setting behind a dark horizon,
under a starry midnight sky.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "branding"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
S = 4  # supersampling factor
SIZE = 1024


def lerp(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def radial_background(size: int) -> Image.Image:
    base = Image.new("RGB", (size, size), (5, 8, 16))
    draw = ImageDraw.Draw(base)
    top = (11, 21, 42)
    bottom = (3, 5, 12)
    for y in range(size):
        draw.line((0, y, size, y), fill=lerp(top, bottom, (y / size) * 0.95))
    # The glow is built small and scaled up; it is a smooth gradient, so no
    # detail is lost and the per-pixel loop stays cheap.
    small = 256
    glow_img = Image.new("L", (small, small), 0)
    gpx = glow_img.load()
    scx, scy = small * 0.5, small * 0.46
    max_d = math.hypot(small * 0.5, small * 0.5)
    for y in range(small):
        for x in range(small):
            d = math.hypot(x - scx, y - scy) / max_d
            gpx[x, y] = int(255 * (max(0.0, 1.0 - d * 1.7) ** 2) * 0.55)
    glow_img = glow_img.resize((size, size), Image.BICUBIC)
    warm = Image.new("RGB", (size, size), (58, 34, 48))
    base.paste(Image.composite(warm, base, glow_img))
    return base


def add_grain(base: Image.Image) -> None:
    """Very subtle deterministic noise keeps large gradients from banding."""
    random.seed(7)
    small = 256
    noise = Image.new("L", (small, small))
    npx = noise.load()
    for y in range(small):
        for x in range(small):
            npx[x, y] = 128 + random.randint(-3, 3)
    noise = noise.resize(base.size, Image.NEAREST).convert("RGB")
    base.paste(Image.blend(base.convert("RGB"), noise, 0.018))


def draw_stars(draw: ImageDraw.ImageDraw, size: int, seed: int = 11) -> None:
    random.seed(seed)
    for _ in range(90):
        x = random.uniform(size * 0.08, size * 0.92)
        y = random.uniform(size * 0.06, size * 0.52)
        radius = random.choice([0.9, 1.1, 1.4, 1.9, 2.6]) * (size / 1024)
        alpha = random.randint(30, 150)
        draw.ellipse(
            (x - radius, y - radius, x + radius, y + radius),
            fill=(235, 240, 255, alpha),
        )
    # a few brighter twinkles
    for _ in range(8):
        x = random.uniform(size * 0.12, size * 0.88)
        y = random.uniform(size * 0.08, size * 0.4)
        r = random.uniform(1.4, 2.2) * (size / 1024)
        draw.ellipse((x - r * 3, y - r, x + r * 3, y + r), fill=(255, 226, 180, 16))
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(255, 244, 220, 190))


def sun_gradient(size: int, radius: float) -> Image.Image:
    """A round sun disc with an amber-to-coral vertical gradient."""
    d = int(radius * 2)
    grad = Image.new("RGBA", (d, d), (0, 0, 0, 0))
    px = grad.load()
    top = (255, 205, 106)
    mid = (255, 154, 74)
    bottom = (255, 82, 70)
    for y in range(d):
        t = y / max(1, d - 1)
        col = lerp(top, mid, t * 1.5) if t < 0.5 else lerp(mid, bottom, (t - 0.5) * 2)
        for x in range(d):
            px[x, y] = (*col, 255)
    mask = Image.new("L", (d, d), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, d - 1, d - 1), fill=255)
    grad.putalpha(mask)
    return grad


def build_mark(size: int, background: bool = True, monochrome: bool = False) -> Image.Image:
    """Draw the full icon at `size` with 4x supersampling."""
    hi = size * S
    if background:
        img = radial_background(hi).convert("RGBA")
        add_grain(img)
    else:
        img = Image.new("RGBA", (hi, hi), (0, 0, 0, 0))

    scale = hi / 1024
    layer = Image.new("RGBA", (hi, hi), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    if background:
        draw_stars(draw, hi)

    # Layout: mark occupies the middle 66% for adaptive-icon safety.
    cx = hi / 2
    sun_r = 232 * scale
    sun_cy = 468 * scale
    horizon_y = 640 * scale
    accent_top = (255, 207, 110)
    accent_bottom = (255, 84, 70)

    if monochrome:
        # Flat single-colour silhouette for themed icons.
        fg = (255, 255, 255, 255)
        draw.pieslice(
            (
                cx - sun_r,
                sun_cy - sun_r,
                cx + sun_r,
                sun_cy + sun_r,
            ),
            180,
            360,
            fill=fg,
        )
        # horizon + two signal lines
        w = 620 * scale
        h = 40 * scale
        draw.rounded_rectangle(
            (cx - w / 2, horizon_y - h / 2, cx + w / 2, horizon_y + h / 2),
            radius=h / 2,
            fill=fg,
        )
        for i, ww in enumerate([0.58, 0.36]):
            w2 = w * ww
            yy = horizon_y + (90 + i * 62) * scale
            draw.rounded_rectangle(
                (cx - w2 / 2, yy - h * 0.32, cx + w2 / 2, yy + h * 0.32),
                radius=h,
                fill=fg,
            )
    else:
        # Halo behind the sun.
        glow = Image.new("RGBA", (hi, hi), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        for i in range(9):
            rr = sun_r * (1.2 + i * 0.11)
            a = int(26 - i * 2.6)
            gd.ellipse((cx - rr, sun_cy - rr, cx + rr, sun_cy + rr), fill=(255, 126, 74, max(0, a)))
        glow = glow.filter(ImageFilter.GaussianBlur(38 * scale))
        layer.alpha_composite(glow)

        sun = sun_gradient(hi, sun_r)
        layer.alpha_composite(sun, (int(cx - sun_r), int(sun_cy - sun_r)))

        # Play cut-out, slightly right of centre for optical balance.
        pr = 108 * scale
        pcx, pcy = cx + 14 * scale, sun_cy + 8 * scale
        tri = [
            (pcx - pr * 0.52, pcy - pr),
            (pcx - pr * 0.52, pcy + pr),
            (pcx + pr, pcy),
        ]
        draw = ImageDraw.Draw(layer)
        draw.polygon(tri, fill=(8, 13, 26, 255))

        # Horizon bar with a warm top rim, overlapping the sun's base.
        bar_w = 640 * scale
        bar_h = 74 * scale
        bar_top = horizon_y
        draw.rounded_rectangle(
            (cx - bar_w / 2, bar_top, cx + bar_w / 2, bar_top + bar_h),
            radius=bar_h / 2,
            fill=(9, 14, 28, 255),
        )
        # warm rim light
        draw.rounded_rectangle(
            (cx - bar_w / 2 + 4 * scale, bar_top + 1 * scale, cx + bar_w / 2 - 4 * scale, bar_top + 7 * scale),
            radius=3 * scale,
            fill=(*accent_bottom, 210),
        )

        # Two shorter "signal" lines below, fading in width and alpha.
        for i, (factor, alpha) in enumerate([(0.52, 190), (0.30, 120)]):
            ww = bar_w * factor
            yy = bar_top + bar_h + (58 + i * 52) * scale
            hh = 24 * scale
            draw.rounded_rectangle(
                (cx - ww / 2, yy, cx + ww / 2, yy + hh),
                radius=hh / 2,
                fill=(*lerp(accent_top, accent_bottom, 0.4 + i * 0.3), alpha),
            )

    img.alpha_composite(layer)
    return img.resize((size, size), Image.LANCZOS)


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG", optimize=True)
    print(f"  {path.relative_to(ROOT)}  {img.size[0]}x{img.size[1]}")


def main() -> None:
    print("NightsunTV icon studio")
    full = build_mark(1024)
    save(full, OUT / "app_icon_1024.png")
    save(full.resize((512, 512), Image.LANCZOS), OUT / "app_icon_512.png")

    # Legacy launcher icons.
    legacy = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, px in legacy.items():
        save(full.resize((px, px), Image.LANCZOS), ANDROID_RES / folder / "ic_launcher.png")

    # Adaptive icon layers.
    foreground = build_mark(1024, background=False)
    save(foreground, OUT / "app_icon_foreground.png")
    # Android foreground canvas is 108dp with a 66dp safe zone. Our art is
    # already inset, so a 0.72 scale keeps it inside the circle/squircle masks.
    for folder, px in {
        "mipmap-mdpi": 108,
        "mipmap-hdpi": 162,
        "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324,
        "mipmap-xxxhdpi": 432,
    }.items():
        save(
            foreground.resize((px, px), Image.LANCZOS),
            ANDROID_RES / folder / "ic_launcher_foreground.png",
        )

    # Background: a simple deep-navy gradient tile.
    bg = Image.new("RGB", (1024, 1024), (7, 11, 22))
    bpx = bg.load()
    for y in range(1024):
        col = lerp((12, 22, 44), (4, 7, 15), y / 1023)
        for x in range(1024):
            bpx[x, y] = col
    save(bg, OUT / "app_icon_background.png")
    for folder, px in {
        "mipmap-mdpi": 108,
        "mipmap-hdpi": 162,
        "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324,
        "mipmap-xxxhdpi": 432,
    }.items():
        save(
            bg.resize((px, px), Image.LANCZOS),
            ANDROID_RES / folder / "ic_launcher_background.png",
        )

    mono = build_mark(1024, background=False, monochrome=True)
    save(mono, OUT / "app_icon_monochrome.png")
    for folder, px in {
        "mipmap-mdpi": 108,
        "mipmap-hdpi": 162,
        "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324,
        "mipmap-xxxhdpi": 432,
    }.items():
        save(
            mono.resize((px, px), Image.LANCZOS),
            ANDROID_RES / folder / "ic_launcher_monochrome.png",
        )

    # Splash mark: transparent, comfortable padding for the Android 12 icon.
    splash = build_mark(640, background=False)
    save(splash, OUT / "splash_mark.png")
    save(full, OUT / "splash_icon.png")

    # Small-size previews used for manual inspection.
    preview = Image.new("RGB", (48 + 72 + 96 + 144 + 192 + 6 * 20, 240), (18, 20, 28))
    x = 20
    for px in (48, 72, 96, 144, 192):
        preview.paste(full.resize((px, px), Image.LANCZOS), (x, (240 - px) // 2))
        x += px + 20
    save(preview, OUT / "size_preview.png")

    print("done")


if __name__ == "__main__":
    main()
