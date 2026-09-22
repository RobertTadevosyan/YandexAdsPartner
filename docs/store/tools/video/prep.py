#!/usr/bin/env python3
"""Slices the 3x renders from docs/store/video/src into the layers promo.html
animates: header, hero card, four KPI cards, chart card, period-metrics card,
apps card, navigation bar, the scrollable page bodies, the accounts sheet.

    python3 prep.py            # writes docs/store/video/layers/<lang>_*.png
"""
import json
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', '..', 'video', 'src')
OUT = os.path.join(HERE, '..', '..', 'video', 'layers')
os.makedirs(OUT, exist_ok=True)

# Card rectangles in 3x pixels, identical for RU and EN (same layout).
CARDS = {
    'header': (48, 213, 1241, 308),
    'hero': (48, 357, 1241, 929),
    'kpi1': (48, 966, 629, 1331),
    'kpi2': (660, 966, 1241, 1331),
    'kpi3': (48, 1362, 629, 1727),
    'kpi4': (660, 1362, 1241, 1727),
    'chart': (48, 1776, 1241, 2567),
    'metrics': (48, 2616, 1241, 3756),
    'apps': (48, 3806, 1241, 4791),
}
PAD = 24  # keep the card shadow


def crop(im, box, pad=PAD, name=None):
    x0, y0, x1, y1 = box
    c = im.crop((max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + 1 + pad), min(im.height, y1 + 1 + pad)))
    if name:
        c.save(os.path.join(OUT, name))
    return c


def uniform_row(im, y, tol=4):
    px = [im.getpixel((x, y)) for x in range(0, im.width, 16)]
    return all(abs(p[i] - px[0][i]) <= tol for p in px for i in range(3))


def nav_top(im):
    """First row from the bottom that is no longer part of the white nav bar."""
    y = im.height - 1
    white = im.getpixel((10, y - 120))
    while y > im.height - 500 and all(abs(c - w) <= 6 for c, w in zip(im.getpixel((10, y)), white)):
        y -= 1
    return y + 1


def sheet_top(im):
    """Top of the accounts bottom sheet: first row from the bottom whose edge
    pixel is no longer the sheet background."""
    y = im.height - 1
    sheet = im.getpixel((10, y - 60))
    while y > 0 and all(abs(c - s) <= 6 for c, s in zip(im.getpixel((10, y)), sheet)):
        y -= 1
    return y + 1


meta = {}
for lang in ('en', 'ru'):
    tall = Image.open(os.path.join(SRC, f'{lang}_overview_tall.png')).convert('RGBA')
    phone = Image.open(os.path.join(SRC, f'{lang}_overview.png')).convert('RGBA')
    bg = tall.getpixel((5, 600))
    for name, box in CARDS.items():
        crop(tall, box, name=f'{lang}_{name}.png')
    nt = nav_top(phone)
    # Pinned app bars (status area + title row), overlaid while the body scrolls.
    phone.crop((0, 0, phone.width, 330)).save(os.path.join(OUT, f'{lang}_ovhead.png'))
    phone.crop((0, nt, phone.width, phone.height)).save(os.path.join(OUT, f'{lang}_nav.png'))
    # Scrollable bodies: everything above the nav bar of the tall render.
    tnt = nav_top(tall)
    tall.crop((0, 0, tall.width, tnt)).save(os.path.join(OUT, f'{lang}_overview_body.png'))
    rtall = Image.open(os.path.join(SRC, f'{lang}_reports_tall.png')).convert('RGBA')
    rnt = nav_top(rtall)
    rtall.crop((0, 0, rtall.width, rnt)).save(os.path.join(OUT, f'{lang}_reports_body.png'))
    rphone = Image.open(os.path.join(SRC, f'{lang}_reports.png')).convert('RGBA')
    rphone.crop((0, 0, rphone.width, 330)).save(os.path.join(OUT, f'{lang}_rphead.png'))
    rphone.crop((0, nav_top(rphone), rphone.width, rphone.height)).save(os.path.join(OUT, f'{lang}_reports_nav.png'))
    acc = Image.open(os.path.join(SRC, f'{lang}_accounts.png')).convert('RGBA')
    st = sheet_top(acc)
    acc.crop((0, st, acc.width, acc.height)).save(os.path.join(OUT, f'{lang}_sheet.png'))
    meta[lang] = {
        'bg': '#%02x%02x%02x' % bg[:3],
        'navTop': nt, 'phoneH': phone.height, 'phoneW': phone.width,
        'overviewBodyH': tnt, 'reportsBodyH': rnt, 'sheetTop': st,
        'cards': CARDS, 'pad': PAD,
    }
    print(lang, 'nav top', nt, 'overview body', tnt, 'reports body', rnt, 'sheet top', st)

json.dump(meta, open(os.path.join(OUT, 'meta.json'), 'w'), indent=1)
print('layers written to', OUT)
