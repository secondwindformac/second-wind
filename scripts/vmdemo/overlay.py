#!/usr/bin/env python3
"""Overlay Mac-style keystroke chips onto decoded demo frames.

Usage: overlay.py FRAMEDIR DURATION  CHIP_SPEC...
  CHIP_SPEC = "label|t0|t1"  (seconds; fade 0.25s in, 0.35s out)
Frames: FRAMEDIR/f%05d.png (from gst pngenc) -> overwritten as f%05d.ppm
(PNG originals removed) ready for encode.sh.
"""
import glob, os, sys
from PIL import Image, ImageDraw, ImageFont

d = sys.argv[1]
dur = float(sys.argv[2])
chips = []
for spec in sys.argv[3:]:
    label, t0, t1 = spec.split('|')
    chips.append((label, float(t0), float(t1)))

frames = sorted(glob.glob(os.path.join(d, 'f*.png')))
n = len(frames)
fps = n / dur
print(f'{n} frames, {fps:.2f} fps')

font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 34)
W, H = 1280, 800
FADE_IN, FADE_OUT = 0.25, 0.35

def make_pill(label):
    tmp = Image.new('RGBA', (1, 1))
    bb = ImageDraw.Draw(tmp).textbbox((0, 0), label, font=font)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    pw, ph = tw + 56, th + 30
    pill = Image.new('RGBA', (pw, ph), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pill)
    pd.rounded_rectangle([0, 0, pw - 1, ph - 1], radius=ph // 2,
                         fill=(18, 18, 24, 216), outline=(255, 255, 255, 60), width=2)
    pd.text(((pw - tw) / 2 - bb[0], (ph - th) / 2 - bb[1]), label,
            font=font, fill=(255, 255, 255, 255))
    return pill

pills = {label: make_pill(label) for label, _, _ in chips}

for i, path in enumerate(frames):
    t = i / fps
    active = [(label, t0, t1) for label, t0, t1 in chips if t0 <= t <= t1]
    img = Image.open(path).convert('RGB')
    for label, t0, t1 in active:
        a = 1.0
        if t - t0 < FADE_IN: a = (t - t0) / FADE_IN
        if t1 - t < FADE_OUT: a = min(a, (t1 - t) / FADE_OUT)
        pill = pills[label]
        if a < 1.0:
            pill = pill.copy()
            alpha = pill.getchannel('A').point(lambda v: int(v * a))
            pill.putalpha(alpha)
        px = (W - pill.width) // 2
        py = 640 - pill.height // 2
        img.paste(pill, (px, py), pill)
    img.save(path[:-4] + '.ppm')
    os.remove(path)
print('overlaid + converted to ppm')
