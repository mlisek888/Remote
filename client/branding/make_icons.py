#!/usr/bin/env python3
"""Generates every Fox Zdalny icon/logo file into client/branding/overlay/.

The overlay mirrors paths inside the RustDesk source tree; the build simply
copies it on top. To use your own artwork, replace icon-1024.png (square,
1024x1024, transparent corners) and run:  python3 make_icons.py --from-png
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "overlay")
FONT = "/usr/share/fonts/truetype/crosextra/Carlito-Bold.ttf"
NAME = "Fox Zdalny"

C1, C2 = (255, 138, 61), (224, 78, 11)   # gradient orange
DARK = (58, 26, 8)

BG = (64, 64, 960, 960, 200)
FRAME = (216, 248, 808, 664, 56)
SCREEN = (256, 288, 768, 624, 24)
STAND = [(456, 664), (568, 664), (596, 756), (428, 756)]
BASE = (352, 748, 672, 796, 24)
FOX = [(380, 324), (470, 398), (554, 398), (644, 324), (622, 468), (512, 584), (402, 468)]
EYES = [(462, 468, 18), (562, 468, 18)]
NOSE = (512, 548, 16)


def p(path):
    full = os.path.join(OUT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    return full


def draw_icon(size=1024):
    s = 4  # supersampling
    W = 1024 * s
    k = lambda v: int(v * s)
    grad = Image.new("RGBA", (W, W))
    gd = ImageDraw.Draw(grad)
    for i in range(W * 2):
        t = i / (W * 2)
        col = tuple(int(C1[j] + (C2[j] - C1[j]) * t) for j in range(3)) + (255,)
        gd.line([(i, 0), (0, i)], fill=col)
    mask = Image.new("L", (W, W), 0)
    x0, y0, x1, y1, r = BG
    ImageDraw.Draw(mask).rounded_rectangle([k(x0), k(y0), k(x1), k(y1)], k(r), fill=255)
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    img.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1, r = FRAME
    d.rounded_rectangle([k(x0), k(y0), k(x1), k(y1)], k(r), fill="white")
    x0, y0, x1, y1, r = SCREEN
    d.rounded_rectangle([k(x0), k(y0), k(x1), k(y1)], k(r), fill=C2 + (255,))
    d.polygon([(k(a), k(b)) for a, b in STAND], fill="white")
    x0, y0, x1, y1, r = BASE
    d.rounded_rectangle([k(x0), k(y0), k(x1), k(y1)], k(r), fill="white")
    d.polygon([(k(a), k(b)) for a, b in FOX], fill="white")
    for cx, cy, r in EYES:
        d.ellipse([k(cx - r), k(cy - r), k(cx + r), k(cy + r)], fill=C2 + (255,))
    cx, cy, r = NOSE
    d.ellipse([k(cx - r), k(cy - r), k(cx + r), k(cy + r)], fill=DARK + (255,))
    return img.resize((size, size), Image.LANCZOS)


def svg():
    rr = lambda t, fill: '<rect x="%d" y="%d" width="%d" height="%d" rx="%d" fill="%s"/>' % (
        t[0], t[1], t[2] - t[0], t[3] - t[1], t[4], fill)
    poly = lambda pts: " ".join("%d,%d" % q for q in pts)
    hx = lambda c: "#%02x%02x%02x" % c
    parts = [
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">',
        '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
        '<stop offset="0" stop-color="%s"/><stop offset="1" stop-color="%s"/></linearGradient></defs>' % (hx(C1), hx(C2)),
        rr(BG, "url(#g)"), rr(FRAME, "#ffffff"), rr(SCREEN, hx(C2)),
        '<polygon points="%s" fill="#ffffff"/>' % poly(STAND), rr(BASE, "#ffffff"),
        '<polygon points="%s" fill="#ffffff"/>' % poly(FOX),
    ]
    for cx, cy, r in EYES:
        parts.append('<circle cx="%d" cy="%d" r="%d" fill="%s"/>' % (cx, cy, r, hx(C2)))
    parts.append('<circle cx="%d" cy="%d" r="%d" fill="%s"/>' % (NOSE[0], NOSE[1], NOSE[2], hx(DARK)))
    parts.append("</svg>\n")
    return "".join(parts)


def logo(icon, text_color):
    W, H = 600, 120  # displayed at max 300x60
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    img.paste(icon.resize((H, H), Image.LANCZOS), (0, 0))
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT, 72)
    d.text((H + 20, H // 2), NAME, font=f, fill=text_color, anchor="lm")
    return img


def main():
    if "--from-png" in sys.argv:
        icon = Image.open(os.path.join(HERE, "icon-1024.png")).convert("RGBA").resize((1024, 1024), Image.LANCZOS)
        svg_text = None
    else:
        icon = draw_icon()
        icon.save(os.path.join(HERE, "icon-1024.png"))
        svg_text = svg()
    rs = lambda n: icon.resize((n, n), Image.LANCZOS)

    for f in ["res/icon.png", "res/mac-icon.png"]:
        icon.save(p(f))
    for n, f in [(32, "res/32x32.png"), (64, "res/64x64.png"), (128, "res/128x128.png"), (256, "res/128x128@2x.png")]:
        rs(n).save(p(f))
    ico_all = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
    icon.save(p("res/icon.ico"), sizes=ico_all)
    icon.save(p("flutter/windows/runner/resources/app_icon.ico"), sizes=ico_all)
    icon.save(p("res/tray-icon.ico"), sizes=[(16, 16), (24, 24), (32, 32), (48, 48)])
    icon.save(p("flutter/macos/Runner/AppIcon.icns"))
    rs(256).save(p("flutter/assets/icon.png"))
    if svg_text:
        for f in ["flutter/assets/icon.svg", "res/scalable.svg"]:
            with open(p(f), "w") as fh:
                fh.write(svg_text)
    logo(icon, (40, 40, 40)).save(p("flutter/assets/logo.png"))
    logo(icon, (40, 40, 40)).save(p("flutter/assets/logo_light.png"))
    logo(icon, (240, 240, 240)).save(p("flutter/assets/logo_dark.png"))
    print("overlay written to", OUT)


if __name__ == "__main__":
    main()
