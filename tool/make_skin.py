#!/usr/bin/env python3
"""Arma una skin de Laika con tus propias imágenes.

Uso:
    tool/make_skin.py <nombre> emoción=imagen [emoción=imagen ...]

Ejemplo:
    tool/make_skin.py mia neutral=~/Imágenes/quieta.png happy=~/Imágenes/feliz.png \\
        sleepingLying=~/Imágenes/dormida.png

Por cada imagen: quita el fondo liso que toca los bordes (blanco, gris, lila…),
recorta lo que sobra, la centra en un cuadro transparente de 512×512 y la guarda
como skins/<nombre>/<emoción>.png. Tus imágenes originales no se tocan.

Emociones: neutral happy greeting laughing inLove surprised impressed doubting
ashamed crying scheming cheeky thinking waking sleeping sleepingLying
(las que falten se reemplazan por otras parecidas; ver docs/SKINS.md).

Opciones:
    --tolerancia N   qué tan parecido al fondo debe ser un color para borrarlo (por defecto 40)
    --sin-fondo      no quitar el fondo (si tus imágenes ya son transparentes)
    --destino DIR    dónde crear la skin (por defecto ./skins; para instalar: ~/.config/laika/skins)

Requiere Pillow (en Arch: sudo pacman -S python-pillow).
"""

import json
import os
import sys
from collections import deque

try:
    from PIL import Image
except ImportError:
    sys.exit("Falta Pillow: sudo pacman -S python-pillow")

MOODS = [
    "neutral", "happy", "greeting", "laughing", "inLove", "surprised", "impressed", "doubting",
    "ashamed", "crying", "scheming", "cheeky", "thinking", "waking", "sleeping", "sleepingLying",
]
SIZE = 512


def remove_background(img: Image.Image, tol: int) -> Image.Image:
    """Borra (hace transparente) el fondo conectado a los bordes.

    Avanza de pixel en pixel mientras el color se parezca al del vecino, así
    funciona también con fondos degradados; un contorno marcado lo detiene.
    """
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0, None))
        q.append((x, h - 1, None))
    for y in range(h):
        q.append((0, y, None))
        q.append((w - 1, y, None))
    while q:
        x, y, prev = q.popleft()
        i = y * w + x
        if seen[i]:
            continue
        p = px[x, y]
        if prev is not None and p[3] and abs(p[0] - prev[0]) + abs(p[1] - prev[1]) + abs(p[2] - prev[2]) > tol:
            continue
        seen[i] = 1
        px[x, y] = (p[0], p[1], p[2], 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                q.append((nx, ny, p))
    return img


def fit(img: Image.Image) -> Image.Image:
    box = img.getbbox()
    if box:
        img = img.crop(box)
    w, h = img.size
    s = (SIZE - 16) / max(w, h)
    img = img.resize((max(1, round(w * s)), max(1, round(h * s))), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.paste(img, ((SIZE - img.width) // 2, SIZE - 8 - img.height), img)
    return out


def main(argv):
    tol, keep_bg, dest = 40, False, "skins"
    args = []
    it = iter(argv)
    for a in it:
        if a == "--tolerancia":
            tol = int(next(it))
        elif a == "--sin-fondo":
            keep_bg = True
        elif a == "--destino":
            dest = os.path.expanduser(next(it))
        elif a in ("-h", "--help"):
            print(__doc__)
            return 0
        else:
            args.append(a)
    if len(args) < 2:
        print(__doc__)
        return 1
    name, pairs = args[0], args[1:]
    out_dir = os.path.join(dest, name)
    os.makedirs(out_dir, exist_ok=True)
    done = []
    for pair in pairs:
        if "=" not in pair:
            sys.exit(f"'{pair}' debe ser emoción=imagen")
        mood, path = pair.split("=", 1)
        if mood not in MOODS:
            sys.exit(f"Emoción desconocida: {mood}. Usa una de: {' '.join(MOODS)}")
        path = os.path.expanduser(path)
        img = Image.open(path)
        if not keep_bg:
            img = remove_background(img, tol)
        fit(img.convert("RGBA")).save(os.path.join(out_dir, f"{mood}.png"))
        done.append(mood)
        print(f"  {mood:14} ← {path}")
    with open(os.path.join(out_dir, "skin.json"), "w") as f:
        json.dump({"name": name}, f, ensure_ascii=False, indent=2)
    missing = [m for m in MOODS if m not in done]
    print(f"Skin '{name}' lista en {out_dir} ({len(done)} emociones).")
    if missing:
        print("Faltan (se usarán otras parecidas):", " ".join(missing))
    print("Elígela en Laika → Ajustes → Skin.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
