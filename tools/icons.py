#!/usr/bin/env python3
"""Genera los íconos de la app (estrella del norte sobre fondo espacial). Uso: python3 tools/icons.py"""
from PIL import Image, ImageDraw, ImageFilter
import os
os.makedirs('icons', exist_ok=True)

def icon(sz, star=0.30, name='icon'):
    im = Image.new('RGB', (sz, sz), (0, 0, 0))
    d = ImageDraw.Draw(im)
    for r in range(sz, 0, -2):  # resplandor azul detrás de la estrella
        t = r / sz
        d.ellipse([sz/2 - r*.75, sz/2 - r*.75, sz/2 + r*.75, sz/2 + r*.75],
                  fill=(int(34*(1-t)**2), int(34*(1-t)**2), int(40*(1-t)**2)))
    m = Image.new('L', (sz, sz), 0)
    s, cx, cy = sz*star, sz/2, sz/2
    w = s*.18
    ImageDraw.Draw(m).polygon([(cx, cy-s), (cx+w, cy-w), (cx+s, cy), (cx+w, cy+w), (cx, cy+s), (cx-w, cy+w), (cx-s, cy), (cx-w, cy-w)], fill=255)
    im.paste((235, 238, 255), (0, 0), m.filter(ImageFilter.GaussianBlur(sz*.045)))
    im.paste((255, 255, 255), (0, 0), m)
    im.save(f'icons/{name}.png')

icon(512, name='icon-512')
icon(192, name='icon-192')
icon(180, name='apple-touch-icon')
icon(512, star=.22, name='maskable-512')
icon(64, star=.36, name='favicon')
print('ok')
