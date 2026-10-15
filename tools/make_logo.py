#!/usr/bin/env python3
"""Genera el recurso limpio del logo LA ALFOMBRA ROJA (assets/LaAlfombraRoja_logo.png y .svg) a partir de
la composicion de la imagen de referencia: corona dorada arriba, LA y ALFOMBRA en serif dorada, ROJA en rojo,
filetes dorados, sobre negro. Es una recreacion vectorial (no un recorte de la foto)."""
import pathlib
from PIL import Image, ImageDraw, ImageFont

root = pathlib.Path(__file__).resolve().parent.parent
out = root / "assets"
out.mkdir(exist_ok=True)
S = 1024
GOLD_TOP, GOLD_BOT = (255, 232, 160), (190, 138, 48)
RED = (212, 24, 42)
FONT_BOLD = "/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf"


def gradient_mask_text(img, text, font, cx, top, fill_top, fill_bot, spacing=0):
    """Dibuja `text` centrado en cx con degradado vertical."""
    d = ImageDraw.Draw(img)
    widths = [d.textlength(ch, font=font) for ch in text]
    total = sum(widths) + spacing * (len(text) - 1)
    x = cx - total / 2
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    for ch, w in zip(text, widths):
        md.text((x, top), ch, font=font, fill=255)
        x += w + spacing
    bbox = mask.getbbox()
    grad = Image.new("RGB", img.size)
    gd = ImageDraw.Draw(grad)
    h = max(1, bbox[3] - bbox[1])
    for y in range(bbox[1], bbox[3]):
        t = (y - bbox[1]) / h
        c = tuple(int(fill_top[i] + (fill_bot[i] - fill_top[i]) * t) for i in range(3))
        gd.line([(0, y), (img.size[0], y)], fill=c)
    img.paste(grad, (0, 0), mask)
    return bbox


def crown(img, cx, y):
    """Corona de 5 puntas con perlas, contorno y banda dorados."""
    d = ImageDraw.Draw(img)
    w, h = 190, 120
    x0 = cx - w / 2
    pts = [(x0, y + h), (x0 - 8, y + 12), (x0 + w * 0.25, y + h * 0.55), (cx, y - 6), (x0 + w * 0.75, y + h * 0.55), (x0 + w + 8, y + 12), (x0 + w, y + h)]
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    ImageDraw.Draw(mask).rectangle([x0 - 2, y + h - 2, x0 + w + 2, y + h + 22], fill=255)
    grad = Image.new("RGB", img.size)
    gd = ImageDraw.Draw(grad)
    for yy in range(int(y - 20), int(y + h + 30)):
        t = max(0, min(1, (yy - y) / (h + 20)))
        gd.line([(0, yy), (img.size[0], yy)], fill=tuple(int(GOLD_TOP[i] + (GOLD_BOT[i] - GOLD_TOP[i]) * t) for i in range(3)))
    img.paste(grad, (0, 0), mask)
    # hueco interior para que se lea como contorno
    inner = [(x0 + 18, y + h - 10), (x0 + 12, y + 34), (x0 + w * 0.25, y + h * 0.66), (cx, y + 24), (x0 + w * 0.75, y + h * 0.66), (x0 + w - 12, y + 34), (x0 + w - 18, y + h - 10)]
    d.polygon(inner, fill=(0, 0, 0))
    for px, py in [(x0 - 8, y + 4), (cx, y - 18), (x0 + w + 8, y + 4)]:
        d.ellipse([px - 9, py - 9, px + 9, py + 9], fill=GOLD_TOP)


def line(img, cx, y, half, color=(214, 164, 70)):
    ImageDraw.Draw(img).rectangle([cx - half, y, cx + half, y + 3], fill=color)


img = Image.new("RGB", (S, S), (0, 0, 0))
cx = S // 2
crown(img, cx, 90)
f_la = ImageFont.truetype(FONT_BOLD, 74)
f_big = ImageFont.truetype(FONT_BOLD, 150)
f_red = ImageFont.truetype(FONT_BOLD, 250)
gradient_mask_text(img, "LA", f_la, cx, 262, GOLD_TOP, GOLD_BOT, spacing=14)
line(img, cx, 372, 300)
gradient_mask_text(img, "ALFOMBRA", f_big, cx, 408, GOLD_TOP, GOLD_BOT, spacing=6)
line(img, cx, 596, 330)
d = ImageDraw.Draw(img)
bbox = d.textbbox((0, 0), "ROJA", font=f_red)
d.text((cx - (bbox[2] - bbox[0]) / 2 - bbox[0], 590), "ROJA", font=f_red, fill=RED)
line(img, cx, 878, 330)
img.save(out / "LaAlfombraRoja_logo.png")

svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {S} {S}" width="{S}" height="{S}">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFE8A0"/><stop offset="1" stop-color="#BE8A30"/></linearGradient>
  </defs>
  <rect width="{S}" height="{S}" fill="#000"/>
  <path d="M417 210 L409 102 L494 145 L512 84 L530 145 L615 102 L607 210 Z" fill="url(#g)"/>
  <rect x="415" y="208" width="194" height="24" fill="url(#g)"/>
  <path d="M435 200 L430 124 L494 160 L512 114 L530 160 L594 124 L589 200 Z" fill="#000"/>
  <circle cx="409" cy="94" r="9" fill="#FFE8A0"/><circle cx="512" cy="66" r="9" fill="#FFE8A0"/><circle cx="615" cy="94" r="9" fill="#FFE8A0"/>
  <g font-family="'Playfair Display','Bodoni MT','Didot','Liberation Serif','Times New Roman',serif" font-weight="700" text-anchor="middle">
    <text x="512" y="320" font-size="74" letter-spacing="14" fill="url(#g)">LA</text>
    <rect x="212" y="372" width="600" height="3" fill="#D6A446"/>
    <text x="512" y="540" font-size="150" letter-spacing="6" fill="url(#g)">ALFOMBRA</text>
    <rect x="182" y="588" width="660" height="3" fill="#D6A446"/>
    <text x="512" y="810" font-size="250" fill="#D4182A">ROJA</text>
    <rect x="182" y="878" width="660" height="3" fill="#D6A446"/>
  </g>
</svg>
"""
(out / "LaAlfombraRoja_logo.svg").write_text(svg, encoding="utf-8")
print("escrito assets/LaAlfombraRoja_logo.png y .svg")
