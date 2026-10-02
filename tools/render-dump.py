#!/usr/bin/env python3
"""Renders a text screen dump written by TvDos.DosDumpScreen.

usage: render-dump.py SCR.DAT [OUT.PNG]

The dump is: width, height (words), then width*height words (character, attribute).
Prints the screen as text (CP866 decoded, DOS glyphs for the control characters) and,
if Pillow and a monospaced font are available, writes a PNG with the VGA colors.
"""
import struct
import sys

GLYPHS = " ☺☻♥♦♣♠•◘○◙♂♀♪♫☼►◄↕‼¶§▬↨↑↓→←∟↔▲▼"
VGA = [(0, 0, 0), (0, 0, 170), (0, 170, 0), (0, 170, 170), (170, 0, 0), (170, 0, 170),
       (170, 85, 0), (170, 170, 170), (85, 85, 85), (85, 85, 255), (85, 255, 85),
       (85, 255, 255), (255, 85, 85), (255, 85, 255), (255, 255, 85), (255, 255, 255)]


def char(b):
    if b < 32:
        return GLYPHS[b]
    if b == 127:
        return "⌂"
    return bytes([b]).decode("cp866", "replace")


def main():
    data = open(sys.argv[1], "rb").read()
    w, h = struct.unpack_from("<HH", data, 0)
    cells = struct.unpack_from("<%dH" % (w * h), data, 4)
    rows = []
    for y in range(h):
        rows.append([(char(c & 255), c >> 8) for c in cells[y * w:(y + 1) * w]])
    for r in rows:
        print("".join(ch for ch, _ in r))
    if len(sys.argv) > 2:
        try:
            from PIL import Image, ImageDraw, ImageFont
        except ImportError:
            print("(no Pillow: no PNG)")
            return
        font = None
        for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
                     "/usr/share/fonts/dejavu/DejaVuSansMono.ttf"):
            try:
                font = ImageFont.truetype(path, 15)
                break
            except OSError:
                pass
        if font is None:
            print("(no font: no PNG)")
            return
        cw, chh = 9, 18
        img = Image.new("RGB", (w * cw, h * chh))
        d = ImageDraw.Draw(img)
        for y, r in enumerate(rows):
            for x, (ch, a) in enumerate(r):
                d.rectangle([x * cw, y * chh, x * cw + cw - 1, y * chh + chh - 1],
                            fill=VGA[(a >> 4) & 15])
                if ch != " ":
                    d.text((x * cw, y * chh), ch, font=font, fill=VGA[a & 15])
        img.save(sys.argv[2])
        print("wrote", sys.argv[2])


main()
