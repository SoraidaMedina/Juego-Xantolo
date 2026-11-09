"""Criaturas de la Cueva del abuelo, en pixel art y escala de grises.

- assets/cueva/chamuco_1.png, chamuco_2.png, chamuco_grito.png : el chamuco (caminar y grito)
- assets/cueva/anima_perdida_1.png, anima_perdida_2.png        : ánimas que vagan sin camino
- assets/cueva/grieta.png                                       : grieta del suelo de donde salen
- assets/sustos/susto_chamuco.png                               : su cara para el susto
Uso: python gen_chamucos.py   (requiere numpy y Pillow)
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
rng = np.random.default_rng(23)
ESCALA = 3


def contorno_y_luz(img, luz=74, borde=8):
    """Agrega contorno negro y una línea de luz fría arriba/izquierda (borde de luna)."""
    a = np.asarray(img).copy()
    alfa = a[..., 1] > 0
    h, w = alfa.shape
    out = a.copy()
    for y in range(h):
        for x in range(w):
            if alfa[y, x]:
                arriba = y == 0 or not alfa[y - 1, x]
                izq = x == 0 or not alfa[y, x - 1]
                if (arriba or izq) and a[y, x, 0] < 120:
                    out[y, x, 0] = max(out[y, x, 0], luz)
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and alfa[ny, nx] and a[ny, nx, 0] < 200:
                    out[y, x] = (borde, 255)
                    break
    return Image.fromarray(out, "LA")


def agrandar(img, esc=ESCALA):
    return img.convert("RGBA").resize((img.width * esc, img.height * esc), Image.NEAREST)


# Las figuras se dibujan grandes (x8) con formas suaves y se reducen a pixeles con umbral:
# así la silueta queda limpia y legible, como sprite hecho a mano.
SS = 8


def a_pixeles(grande, w, h, umbral=0.5):
    chico = grande.resize((w, h), Image.BOX)
    a = np.asarray(chico).copy()
    a[..., 1] = np.where(a[..., 1] > umbral * 255, 255, 0)
    return a


def borde_luz(a, tono, lado=1):
    """Ilumina el borde del lado de la luz (la vela de Xochik) para que se lea en lo oscuro."""
    h, w = a.shape[:2]
    out = a.copy()
    for y in range(h):
        for x in range(w):
            if a[y, x, 1] == 0:
                continue
            nx = x + lado
            if nx < 0 or nx >= w or a[y, nx, 1] == 0 or y == 0 or a[y - 1, x, 1] == 0:
                out[y, x, 0] = max(out[y, x, 0], tono)
    return out


# ---------------------------------------------------------------- chamuco
def chamuco(fase=0, grito=False):
    W, H = 34, 60
    g = Image.new("LA", (W * SS, H * SS), (0, 0))
    d = ImageDraw.Draw(g)
    c = (22, 255)
    S = lambda *p: [(x * SS, y * SS) for x, y in p]   # noqa: E731
    paso = math.sin(fase * math.pi)
    inclina = -3 if grito else 0
    hx, hy = 21 + inclina * 0.3, 11 + (-2 if grito else 0)
    # piernas flacas, rodillas dobladas
    for lado, desf in ((-1, 0.0), (1, math.pi)):
        a = math.sin(fase * math.pi + desf) * 3
        d.line(S((17 + lado * 2, 37), (19 + lado * 2 + a, 47), (16 + lado * 2 + a, 56)), fill=c, width=int(3.4 * SS))
        d.line(S((16 + lado * 2 + a, 56), (20 + lado * 2 + a, 58)), fill=c, width=int(1.6 * SS))
    # torso: hombros anchos, cintura delgada, harapos
    d.polygon(S((10, 20), (28, 19), (25, 33), (24, 40), (12, 40), (12, 32)), fill=c)
    for k in range(6):
        x = 12 + k * 2.2
        d.polygon(S((x, 39), (x + 2.4, 39), (x + 1 + (k % 2), 43 + (k * 7) % 3)), fill=c)
    # cuello y cabeza alargada
    d.line(S((19, 20), (hx, hy + 4)), fill=c, width=int(3 * SS))
    d.ellipse(S((hx - 5, hy - 6), (hx + 5, hy + 6)), fill=c)
    d.polygon(S((hx + 2, hy + 1), (hx + 8, hy + 3), (hx + 2, hy + 6)), fill=c)       # hocico
    # cuernos de chivo
    d.line(S((hx - 2, hy - 4), (hx - 6, hy - 9), (hx - 11, hy - 10), (hx - 13, hy - 7)), fill=c, width=int(2.6 * SS))
    d.line(S((hx + 2, hy - 5), (hx + 1, hy - 10), (hx - 3, hy - 13)), fill=c, width=int(2.4 * SS))
    # brazos larguísimos
    if grito:
        brazos = [((26, 21), (31, 12), (33, 3)), ((12, 21), (6, 12), (3, 4))]
    else:
        brazos = [((26, 21), (29 + paso * 2, 33), (30 + paso * 3, 46)), ((12, 21), (11 - paso * 2, 33), (13 - paso * 3, 46))]
    for h0, codo, mano in brazos:
        d.line(S(h0, codo, mano), fill=c, width=int(3.0 * SS))
        dy = -1 if grito else 1
        for gx in (-1.6, 0, 1.6):   # garras largas
            d.line(S(mano, (mano[0] + gx, mano[1] + dy * 5)), fill=c, width=int(1.3 * SS))
    a = a_pixeles(g, W, H, 0.45)
    a = borde_luz(a, 78, 1)
    img = Image.fromarray(a, "LA")
    d = ImageDraw.Draw(img)
    ex, ey = int(hx), int(hy)
    for ox in (ex, ex + 3):   # ojos huecos que brillan
        d.point((ox, ey - 1), fill=(255, 255))
        d.point((ox, ey), fill=(170, 255))
    if grito:
        d.line([(ex + 1, ey + 3), (ex + 6, ey + 4)], fill=(0, 255))
        d.line([(ex + 1, ey + 5), (ex + 5, ey + 5)], fill=(0, 255))
        for tx in (ex + 2, ex + 4):
            d.point((tx, ey + 3), fill=(235, 255))
    else:
        d.point((ex + 4, ey + 3), fill=(200, 255))   # colmillo
    return agrandar(img)


# ---------------------------------------------------------------- ánima perdida
def anima(fase=0):
    W, H = 30, 52
    g = Image.new("LA", (W * SS, H * SS), (0, 0))
    d = ImageDraw.Draw(g)
    S = lambda *p: [(x * SS, y * SS) for x, y in p]   # noqa: E731
    b = (226, 255)
    ola = math.sin(fase * math.pi)
    # cabeza ladeada y cuerpo que se estira hacia abajo
    d.ellipse(S((9, 3), (20, 17)), fill=b)
    d.polygon(S((8, 12), (21, 12), (23, 30), (6, 30)), fill=b)
    for k in range(6):   # jirones
        x = 6.5 + k * 3
        largo = 40 + ((k * 5) % 4) * 2 + ola * (2 if k % 2 else -2)
        d.polygon(S((x - 1.6, 28), (x + 1.6, 28), (x + ola * 1.5 + (k % 2), largo)), fill=b)
    # brazos flacos que buscan hacia adelante
    d.line(S((20, 15), (26, 19), (29, 17)), fill=b, width=int(1.6 * SS))
    d.line(S((9, 16), (4, 22), (2, 27)), fill=b, width=int(1.6 * SS))
    a = a_pixeles(g, W, H, 0.4)
    # transparencia: más tenue hacia abajo
    for y in range(H):
        a[y, :, 1] = (a[y, :, 1] * (1.0 - 0.55 * max(0, y - 22) / (H - 22))).astype(np.uint8)
        a[y, :, 0] = np.where(a[y, :, 1] > 0, 226 - y, 0)
    img = Image.fromarray(a, "LA")
    d = ImageDraw.Draw(img)
    # ojos sesgados y boca que grita, estirada hacia abajo
    d.polygon([(11, 8), (14, 9), (14, 11), (11, 10)], fill=(8, 255))
    d.polygon([(16, 9), (19, 8), (19, 10), (16, 11)], fill=(8, 255))
    d.ellipse([13, 12, 16, 20], fill=(8, 255))
    return agrandar(img)


# ---------------------------------------------------------------- grieta
def grieta():
    W, H = 50, 14
    img = Image.new("LA", (W, H), (0, 0))
    d = ImageDraw.Draw(img)
    arriba, abajo = [], []
    for x in range(1, W, 2):
        mitad = 4.2 * math.sin(math.pi * x / W) ** 0.7 + rng.uniform(0, 1.2)
        y = 6 + rng.uniform(-1.2, 1.2)
        arriba.append((x, y - mitad))
        abajo.append((x, y + mitad * 0.7))
    # resplandor alrededor de la grieta
    d.polygon([(x, y - 1.5) for x, y in arriba] + [(x, y + 1.5) for x, y in abajo[::-1]], fill=(120, 150))
    d.polygon(arriba + abajo[::-1], fill=(0, 255))
    for (x, y) in arriba[2:-2:2]:
        d.point((x, int(y)), fill=(200, 255))
    return agrandar(img)


# ---------------------------------------------------------------- susto
def susto():
    RW, RH = 384, 216
    v = np.zeros((RH, RW), np.float32) + 0.04
    v += 0.05 * rng.random((RH, RW))
    img = Image.fromarray((v * 255).astype(np.uint8), "L")
    d = ImageDraw.Draw(img)
    cx, cy = 192, 120
    # cuernos
    for s in (-1, 1):
        pts = [(cx + s * 40, cy - 50), (cx + s * 70, cy - 95), (cx + s * 110, cy - 120),
               (cx + s * 92, cy - 92), (cx + s * 64, cy - 52)]
        d.polygon(pts, fill=34)
        d.line(pts[:3], fill=70)
    # cabeza
    d.ellipse([cx - 92, cy - 78, cx + 92, cy + 98], fill=26)
    d.arc([cx - 92, cy - 78, cx + 92, cy + 98], 190, 300, fill=80, width=3)
    # cuencas y ojos que brillan
    for s in (-1, 1):
        ox = cx + s * 40
        d.polygon([(ox - 30, cy - 30), (ox + 30, cy - 20 - s * 6), (ox + 22, cy + 6), (ox - 24, cy + 2)], fill=6)
        d.ellipse([ox - 14, cy - 18, ox + 14, cy + 2], fill=250)
        d.ellipse([ox - 4, cy - 15, ox + 4, cy - 1], fill=0)
    # boca abierta con dientes
    d.polygon([(cx - 60, cy + 30), (cx + 60, cy + 30), (cx + 36, cy + 84), (cx - 36, cy + 84)], fill=0)
    for k in range(-5, 6):
        x = cx + k * 11
        d.polygon([(x - 5, cy + 30), (x + 5, cy + 30), (x, cy + 46 + abs(k))], fill=215)
        d.polygon([(x - 4, cy + 84), (x + 4, cy + 84), (x, cy + 70)], fill=170)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    a = np.asarray(img, np.float32) / 255.0
    yy, xx = np.mgrid[0:RH, 0:RW]
    dd = np.sqrt(((xx - RW / 2) / (RW / 2)) ** 2 + ((yy - RH / 2) / (RH / 2)) ** 2)
    a *= np.clip(1.25 - 0.7 * dd ** 2, 0.15, 1)
    a = np.round(a * 12) / 12
    return Image.fromarray((a * 255).astype(np.uint8), "L").resize((RW * 3, RH * 3), Image.NEAREST)


def main():
    cueva = os.path.join(RAIZ, "assets/cueva")
    os.makedirs(cueva, exist_ok=True)
    chamuco(0.0).save(os.path.join(cueva, "chamuco_1.png"))
    chamuco(1.0).save(os.path.join(cueva, "chamuco_2.png"))
    chamuco(0.5, grito=True).save(os.path.join(cueva, "chamuco_grito.png"))
    anima(0.0).save(os.path.join(cueva, "anima_perdida_1.png"))
    anima(1.0).save(os.path.join(cueva, "anima_perdida_2.png"))
    grieta().save(os.path.join(cueva, "grieta.png"))
    susto().save(os.path.join(RAIZ, "assets/sustos/susto_chamuco.png"))
    print("ok chamucos")


if __name__ == "__main__":
    main()
