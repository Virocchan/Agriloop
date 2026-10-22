#!/usr/bin/env python3
"""
AgriLoop brand asset pipeline.

Turns the raw logo artwork into every icon the project needs:

  * web/icons/Icon-{192,512}.png            standard launcher icon
  * web/icons/Icon-maskable-{192,512}.png   Android adaptive (safe zone)
  * web/favicon.png                          browser tab
  * android/app/src/main/res/mipmap-*/ic_launcher.png
  * ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png  (opaque)
  * assets/images/agriloop_mark.png          symbol, transparent
  * assets/images/agriloop_logo.png          symbol + wordmark, transparent

The source artwork is a stock preview whose transparency checkerboard and
watermark are baked into the pixels, so the real transparency is recovered
here:

  1. flood-fill the neutral (grey) pixels inwards from the borders -> the
     outer checkerboard and the watermark strokes
  2. drop the neutral pixels still trapped inside the artwork -> checkerboard
     squares the loop encloses
  3. keep warm bright pixels (luma >= 220) -> the cream leaf highlight
  4. partial alpha on the desaturated edge pixels -> smooth edges

Usage:
    python3 tool/make_brand_assets.py [source_image]
"""
import json
import os
import sys
from collections import deque

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_SOURCE = os.path.expanduser("~/Downloads/agriloop.jpeg")

BRAND_BG = (13, 21, 17)        # #0D1511 — the app's dark surface
NEUTRAL_SAT = 26                # max channel spread for a pixel to be grey
EDGE_SAT = 45                   # saturation range treated as an anti-aliased edge
KEEP_BRIGHT_LUMA = 220          # warm highlights (the cream leaf vein) survive


def saturation(c):
    return max(c) - min(c)


def luma(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def build_alpha(img):
    """Returns a PIL 'L' image with the recovered transparency."""
    w, h = img.size
    px = img.load()

    neutral = bytearray(w * h)
    edge = bytearray(w * h)
    for y in range(h):
        row = y * w
        for x in range(w):
            c = px[x, y]
            s = saturation(c)
            if s < NEUTRAL_SAT:
                neutral[row + x] = 1
            elif s < EDGE_SAT:
                edge[row + x] = 1

    # 1. flood fill the grey background inwards from the borders
    seen = bytearray(w * h)
    queue = deque()

    def seed(x, y):
        i = y * w + x
        if neutral[i] and not seen[i]:
            seen[i] = 1
            queue.append((x, y))

    for x in range(w):
        seed(x, 0)
        seed(x, h - 1)
    for y in range(h):
        seed(0, y)
        seed(w - 1, y)

    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h:
                i = ny * w + nx
                if neutral[i] and not seen[i]:
                    seen[i] = 1
                    queue.append((nx, ny))

    # 2. alpha
    alpha = Image.new("L", (w, h), 255)
    apx = alpha.load()
    for y in range(h):
        row = y * w
        for x in range(w):
            i = row + x
            c = px[x, y]
            if neutral[i]:
                if seen[i]:
                    apx[x, y] = 0                      # outer checkerboard
                elif luma(c) < KEEP_BRIGHT_LUMA:
                    apx[x, y] = 0                      # checker trapped inside
                else:
                    apx[x, y] = 255                    # cream leaf highlight
            elif edge[i]:
                # partial alpha so the outline stays smooth
                s = saturation(c)
                apx[x, y] = int(255 * (s - NEUTRAL_SAT) / (EDGE_SAT - NEUTRAL_SAT))

    return alpha


def split_mark_and_lockup(rgba):
    """Cuts the artwork at the full-width empty band between the symbol and
    the wordmark. Returns (mark, lockup)."""
    alpha = rgba.getchannel("A")
    w, h = rgba.size
    apx = alpha.load()

    rows_empty = [all(apx[x, y] == 0 for x in range(w)) for y in range(h)]

    # content extent
    content = [y for y in range(h) if not rows_empty[y]]
    if not content:
        return rgba, rgba
    first, last = content[0], content[-1]

    # widest empty band *between* the first and last content row
    best = None
    start = None
    for y in range(first, last + 1):
        if rows_empty[y] and start is None:
            start = y
        elif not rows_empty[y] and start is not None:
            if best is None or (y - start) > (best[1] - best[0]):
                best = (start, y - 1)
            start = None
    if best is None:
        return rgba, rgba

    # the wordmark sits below the gap, so the lockup is the whole artwork
    mark = rgba.crop((0, 0, w, best[0]))
    lockup = rgba
    return mark, lockup


def trim(img):
    bbox = img.getchannel("A").getbbox()
    return img.crop(bbox) if bbox else img


def on_brand(mark, size, scale, background=BRAND_BG):
    """Renders the mark centred on the brand background at the given scale."""
    canvas = Image.new("RGB", (size, size), background)
    target = int(size * scale)
    art = trim(mark).resize((target, target), Image.LANCZOS)
    offset = (size - art.size[0]) // 2
    canvas.paste(art, (offset, offset), art)
    return canvas


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG", optimize=True)
    print(f"  {os.path.relpath(path, ROOT)}  {img.size[0]}x{img.size[1]}")


def main():
    source = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SOURCE
    if not os.path.exists(source):
        raise SystemExit(f"source artwork not found: {source}")

    print(f"source: {source}")
    raw = Image.open(source).convert("RGB")
    print(f"  {raw.size[0]}x{raw.size[1]}")

    alpha = build_alpha(raw)
    rgba = raw.convert("RGBA")
    rgba.putalpha(alpha)

    mark, lockup = split_mark_and_lockup(rgba)
    mark = trim(mark)
    lockup = trim(lockup)
    print(f"  symbol   {mark.size[0]}x{mark.size[1]}")
    print(f"  lockup   {lockup.size[0]}x{lockup.size[1]}")

    # --- in-app assets (transparent) -----------------------------------
    save(mark, os.path.join(ROOT, "assets/images/agriloop_mark.png"))
    save(lockup, os.path.join(ROOT, "assets/images/agriloop_logo.png"))

    # --- web ------------------------------------------------------------
    web = os.path.join(ROOT, "web")
    for size in (192, 512):
        save(on_brand(mark, size, 0.86), os.path.join(web, f"icons/Icon-{size}.png"))
        # maskable: artwork inside the 80% safe zone
        save(on_brand(mark, size, 0.58), os.path.join(web, f"icons/Icon-maskable-{size}.png"))
    save(on_brand(mark, 64, 0.92), os.path.join(web, "favicon.png"))

    # --- android launcher icons ------------------------------------------
    for folder, size in (("mipmap-mdpi", 48), ("mipmap-hdpi", 72), ("mipmap-xhdpi", 96),
                          ("mipmap-xxhdpi", 144), ("mipmap-xxxhdpi", 192)):
        save(on_brand(mark, size, 0.84),
             os.path.join(ROOT, f"android/app/src/main/res/{folder}/ic_launcher.png"))

    # --- ios app icon (opaque, no alpha allowed) -------------------------
    ios_dir = os.path.join(ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    with open(os.path.join(ios_dir, "Contents.json")) as fh:
        manifest = json.load(fh)

    for entry in manifest["images"]:
        filename = entry.get("filename")
        if not filename:
            continue
        points = float(entry["size"].split("x")[0])
        scale = float(entry["scale"].rstrip("x"))
        pixels = int(round(points * scale))
        # iOS icons are square and fully opaque
        icon = on_brand(mark, pixels, 0.80)
        save(icon, os.path.join(ios_dir, filename))

    print("\ndone.")


if __name__ == "__main__":
    main()
