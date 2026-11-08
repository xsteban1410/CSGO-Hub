#!/usr/bin/env python3
"""Draws a simple preview.png (640x360) for an item from its item.toml, when there is no screenshot.
usage: tools/make_preview.py items/<id> [...]   (needs Pillow: pip install pillow)
A real screenshot of the mode or plugin is better: crop it to 16:9 and keep it under 300 KB."""
import sys, tomllib, pathlib
from PIL import Image, ImageDraw, ImageFont

COLORS = {  # top and bottom of the gradient, by category or kind
    'classic': ((38, 70, 120), (16, 24, 40)), 'competitive': ((120, 60, 30), (30, 18, 12)),
    'deathmatch': ((130, 30, 40), (30, 10, 14)), 'weapons': ((70, 90, 40), (18, 24, 12)),
    'fun': ((110, 40, 120), (28, 12, 34)), 'objective': ((30, 100, 100), (10, 28, 30)),
    'pve': ((40, 110, 50), (10, 30, 14)), 'plugin': ((60, 60, 70), (18, 18, 24)),
    'admin': ((150, 110, 20), (36, 26, 6)), 'pack': ((40, 80, 140), (10, 20, 40)),
}

def font(size, bold=True):
    for name in (('NotoSans-Bold.ttf' if bold else 'NotoSans-Regular.ttf'), 'DejaVuSans-Bold.ttf', 'DejaVuSans.ttf'):
        for base in ('/usr/share/fonts/noto', '/usr/share/fonts/truetype/noto', '/usr/share/fonts/TTF', '/usr/share/fonts/truetype/dejavu'):
            p = pathlib.Path(base) / name
            if p.is_file():
                return ImageFont.truetype(str(p), size)
    return ImageFont.load_default()

def wrap(draw, text, f, width):
    lines, line = [], ''
    for w in text.split():
        t = (line + ' ' + w).strip()
        if draw.textlength(t, font=f) > width and line:
            lines.append(line)
            line = w
        else:
            line = t
    return lines + [line] if line else lines

def make(d):
    it = tomllib.loads((d / 'item.toml').read_text())
    tags = it.get('tags', [])
    key = next((t for t in tags if t in COLORS), None) or ('admin' if 'admin' in tags else it['kind'])
    top, bottom = COLORS.get(key, COLORS['plugin'])
    W, H = 640, 360
    img = Image.new('RGB', (W, H))
    px = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        px.line([(0, y), (W, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    for x in range(-H, W, 28):  # thin diagonal stripes
        px.line([(x, H), (x + H, 0)], fill=tuple(min(255, c + 10) for c in top), width=1)
    px.rectangle([0, 0, 8, H], fill=(240, 180, 40))
    px.text((40, 40), (key if key != it['kind'] else it['kind']).upper(), font=font(20), fill=(240, 180, 40))
    title = it['name']['en']
    f = font(54)
    y = 80
    for line in wrap(px, title, f, W - 80)[:2]:
        px.text((40, y), line, font=f, fill=(255, 255, 255))
        y += 64
    small = font(20, bold=False)
    for line in wrap(px, it['description']['en'], small, W - 80)[:4]:
        px.text((40, y + 10), line, font=small, fill=(220, 220, 225))
        y += 28
    px.text((40, H - 44), 'CSGO-Hub', font=font(18), fill=(200, 200, 210))
    img.save(d / 'preview.png', optimize=True)

for a in sys.argv[1:]:
    make(pathlib.Path(a))
