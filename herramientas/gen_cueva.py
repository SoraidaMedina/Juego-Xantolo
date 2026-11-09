"""Arte de la Cueva del abuelo (nivel 4), en escala de grises y pixel art.

- assets/cueva/cueva_1.png, cueva_2.png : fondo de las dos pantallas (1152x648 c/u).
  Piso en y=560; abismos en x 560-640 (pantalla 1) y 700-780 (pantalla 2).
- assets/cueva/balero.png               : el juguete que el abuelo talló (objeto con memoria).
- assets/cueva/recuerdo_N_x.png         : los recuerdos sin texto, como teatro de sombras.
Uso: python gen_cueva.py ../assets/cueva   (requiere numpy y Pillow)
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
rng = np.random.default_rng(11)

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def ruido(w, h, escala, semilla):
    r = np.random.default_rng(semilla)
    gw, gh = max(2, w // escala + 2), max(2, h // escala + 2)
    rejilla = (r.random((gh, gw)) * 255).astype(np.uint8)
    img = Image.fromarray(rejilla).resize((gw * escala, gh * escala), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32)[:h, :w] / 255.0


def fractal(w, h, escala, semilla, octavas=4):
    total = np.zeros((h, w), np.float32)
    amp, suma = 1.0, 0.0
    for o in range(octavas):
        total += ruido(w, h, max(2, escala >> o), semilla + o * 31) * amp
        suma += amp
        amp *= 0.5
    return total / suma


def tramar(v, niveles):
    """Cuantiza a pocos tonos con tramado ordenado (aspecto de pixel art)."""
    h, w = v.shape
    umbral = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w] - 0.5
    niveles = np.array(niveles, np.float32)
    paso = np.diff(niveles).mean()
    v2 = v + umbral * paso * 0.9
    idx = np.abs(v2[..., None] - niveles[None, None, :]).argmin(axis=2)
    return niveles[idx]


# =====================================================================
# Fondo de la cueva (tira continua de 2 pantallas a media resolución)
# =====================================================================
W, H = 1152, 324          # media resolución (se agranda x2)
PISO = 280
ABISMOS = [(280, 320), (576 + 350, 576 + 390)]
GRIETAS = [180, 470, 576 + 130, 576 + 430]     # rayos de luz que bajan del techo


def formacion(d, x, base, alto, ancho, tono, hacia_abajo=False):
    """Estalagmita (o estalactita) irregular, con el lado izquierdo iluminado."""
    sentido = 1 if hacia_abajo else -1
    pasos = max(4, alto // 5)
    izq, der = [], []
    for k in range(pasos + 1):
        t = k / pasos
        mitad = ancho * (1 - t) ** 1.3 + 0.6
        y = base + sentido * alto * t
        ruido_x = rng.uniform(-1.6, 1.6) * (1 - t)
        izq.append((x - mitad + ruido_x, y))
        der.append((x + mitad + ruido_x * 0.5, y))
    d.polygon(izq + der[::-1], fill=tono)
    d.line(izq[1:-1], fill=min(255, tono + 26))
    # anillos de crecimiento
    for k in range(2, pasos, 3):
        d.line([izq[k], der[k]], fill=max(0, tono - 8))


def fondo_cueva():
    # Pared: escurrimientos verticales de roca (flowstone) + bultos grandes
    escurre = np.asarray(Image.fromarray((fractal(W, H // 8 + 2, 6, 3, 3) * 255).astype(np.uint8))
                         .resize((W, H), Image.BICUBIC), np.float32) / 255.0
    v = 0.10 + 0.20 * escurre + 0.12 * fractal(W, H, 56, 1) + 0.05 * fractal(W, H, 6, 2, 2)
    grande = fractal(W, H + 4, 40, 5)
    v += 0.9 * (grande[:-4] - grande[4:])[:H]          # relieve iluminado desde arriba
    yy = np.linspace(0, 1, H)[:, None]
    v *= 0.55 + 0.6 * np.exp(-((yy - 0.6) ** 2) / 0.06)
    v = np.clip(v, 0.03, 0.55)

    img = Image.fromarray((v * 255).astype(np.uint8), "L")
    d = ImageDraw.Draw(img)

    # Pantalla 1: un par de grabados sueltos. Pantalla 2: el gran mural de los antepasados.
    petroglifos(d, 360, 150)
    mural(d, 576 + 90, 118)

    # Estalagmitas: lejanas (claras, con niebla) y cercanas (oscuras, grandes)
    for x in range(6, W, 17):
        if rng.random() < 0.5:
            formacion(d, x + int(rng.integers(-5, 5)), PISO, int(rng.integers(14, 46)), int(rng.integers(4, 9)),
                      int(rng.integers(52, 70)))
    for x in range(20, W, 41):
        if rng.random() < 0.6 and not any(a - 20 < x < b + 20 for a, b in ABISMOS):
            formacion(d, x + int(rng.integers(-10, 10)), PISO + 1, int(rng.integers(40, 96)),
                      int(rng.integers(9, 18)), int(rng.integers(20, 34)))
    # Columnas donde se unen techo y piso
    for cx in (330, 576 + 336):
        ancho = int(rng.integers(14, 22))
        for y in range(0, PISO):
            t = abs(y - PISO * 0.45) / (PISO * 0.55)
            w = ancho * (0.55 + 0.6 * t ** 2) + rng.uniform(-1, 1)
            d.line([(cx - w, y), (cx + w, y)], fill=int(26 + 8 * (1 - t)))
            d.point((cx - w, y), fill=60)

    v = np.asarray(img, np.float32) / 255.0

    # Techo irregular con estalactitas
    techo = 30 + 26 * fractal(W, 1, 40, 9, 3)[0] + 10 * fractal(W, 1, 9, 10, 2)[0]
    textura = 0.04 + 0.07 * fractal(W, H, 6, 12, 2)
    for x in range(W):
        y = int(techo[x])
        v[:y, x] = textura[:y, x]
        v[y:y + 2, x] = 0.18
    img = Image.fromarray((np.clip(v, 0, 1) * 255).astype(np.uint8), "L")
    d = ImageDraw.Draw(img)
    x = 0
    while x < W:
        x += int(rng.integers(7, 24))
        if x >= W:
            break
        y = int(techo[min(x, W - 1)])
        largo = int(rng.integers(6, 58))
        formacion(d, x, y - 2, largo, int(rng.integers(3, 8)), int(rng.integers(12, 26)), hacia_abajo=True)
        if rng.random() < 0.35:   # gota colgando
            d.point((x, y + largo + 2), fill=150)
    raices(d, techo, 10, 520)
    repisa(d, 576 + 380, 196)
    v = np.asarray(img, np.float32) / 255.0

    # Rayos de luz por las grietas del techo
    luz = Image.new("L", (W, H), 0)
    dl = ImageDraw.Draw(luz)
    for gx in GRIETAS:
        y0 = int(techo[gx])
        inclina = int(rng.integers(-25, 25))
        dl.polygon([(gx - 4, y0), (gx + 5, y0), (gx + 34 + inclina, PISO), (gx - 30 + inclina, PISO)], fill=80)
        dl.line([(gx - 3, y0 - 1), (gx + 4, y0 - 1)], fill=255)
    luz = luz.filter(ImageFilter.GaussianBlur(6))
    lz = np.asarray(luz, np.float32) / 255.0
    caida = np.clip((np.arange(H)[:, None] - 20) / (PISO - 20), 0, 1)
    v += lz * (0.6 - 0.3 * caida)

    # Piso de roca con borde irregular
    piso = 0.10 + 0.10 * fractal(W, H, 10, 20, 3)
    v[PISO:, :] = piso[PISO:, :]
    for x in range(W):
        v[PISO, x] = 0.44 if rng.random() < 0.85 else 0.3
        v[PISO + 1, x] = 0.28
        v[PISO + 2, x] = 0.2
    for x in range(0, W, 2):     # piedritas
        if rng.random() < 0.2:
            y = PISO + int(rng.integers(5, H - PISO - 2))
            v[y, x] = 0.26
            v[y + 1, x] = 0.06
    # Abismos
    for a, b in ABISMOS:
        for x in range(a - 3, b + 3):
            borde = 0 if a <= x < b else int(rng.integers(0, 4))
            v[PISO + borde:, x] = 0.0
        for k in range(1, 18):   # paredes del abismo, que se pierden en lo negro
            v[PISO + k, a:a + 2] = 0.16 * (1 - k / 18)
            v[PISO + k, b - 2:b] = 0.10 * (1 - k / 18)

    # Entrada (luz de luna) a la izquierda
    xx = np.arange(W)[None, :]
    v += 0.32 * np.exp(-xx / 60.0) * (np.arange(H)[:, None] < PISO)
    img = Image.fromarray((np.clip(v, 0, 1) * 255).astype(np.uint8), "L")
    helechos(ImageDraw.Draw(img), 0, 70)
    v = np.asarray(img, np.float32) / 255.0

    # Salida al amanecer, a la derecha: boca irregular de la cueva
    salida = Image.new("L", (W, H), 0)
    ds = ImageDraw.Draw(salida)
    cx, cy = W - 4, 205
    pts = []
    for k in range(40):
        a = math.pi / 2 + math.pi * k / 39
        r = 1 + 0.07 * math.sin(k * 0.45) + 0.04 * math.sin(k * 1.3) + rng.uniform(-0.015, 0.015)
        pts.append((cx + math.cos(a) * 62 * r, cy - math.sin(a) * 92 * r))
    pts.append((cx + 10, cy - 92))
    pts.append((cx + 10, PISO + 2))
    ds.polygon(pts, fill=255)
    boca = np.asarray(salida, np.float32) / 255.0
    cielo = 0.96 - 0.25 * np.clip((np.arange(H)[:, None] - 110) / 170.0, 0, 1)
    v = np.where(boca > 0.5, cielo, v)
    # cerros lejanos y el pueblo al amanecer, vistos desde la boca
    for x in range(W - 75, W):
        cerro = PISO - 34 + 10 * math.sin(x * 0.09) + 6 * math.sin(x * 0.23)
        for y in range(int(cerro), PISO + 2):
            if boca[y, x] > 0.5:
                v[y, x] = 0.70 if y < PISO - 12 else 0.62
    # hierbas y ramas en la boca, a contraluz
    img = Image.fromarray((np.clip(v, 0, 1) * 255).astype(np.uint8), "L")
    d = ImageDraw.Draw(img)
    for k in range(26):
        bx = W - 66 + k * 2.6 + rng.uniform(-1, 1)
        alto = rng.uniform(6, 22)
        d.line([(bx, PISO), (bx + rng.uniform(-4, 4), PISO - alto)], fill=10)
    v = np.asarray(img, np.float32) / 255.0
    brillo = Image.fromarray((boca * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(28))
    v += 0.55 * np.asarray(brillo, np.float32) / 255.0 * (np.arange(H)[:, None] < PISO + 2)

    # Rocas del frente, muy oscuras, en la parte de abajo
    img = Image.fromarray((np.clip(v, 0, 1) * 255).astype(np.uint8), "L")
    d = ImageDraw.Draw(img)
    x = 0
    while x < W:
        r = int(rng.integers(8, 20))
        cx2 = x + r
        if not any(a - 10 < cx2 < b + 10 for a, b in ABISMOS):
            d.ellipse([cx2 - r, H - r // 2 - 4, cx2 + r, H + r], fill=6)
            d.arc([cx2 - r, H - r // 2 - 4, cx2 + r, H + r], 200, 290, fill=30)
        x += int(rng.integers(14, 40))
    v = np.asarray(img, np.float32) / 255.0

    niveles = [0.0, 0.04, 0.08, 0.12, 0.17, 0.23, 0.30, 0.38, 0.48, 0.62, 0.78, 0.92]
    v = tramar(np.clip(v, 0, 1), niveles)
    return Image.fromarray((v * 255).astype(np.uint8), "L")


def raices(d, techo, x0, x1):
    """Raíces que cuelgan del techo cerca de la entrada (la cueva está bajo el monte)."""
    for x in range(x0, x1, 9):
        if rng.random() < 0.55:
            y = int(techo[x]) + 1
            largo = int(rng.integers(18, 75)) * (1.4 if x < 140 else 1.0)
            px, py = x, y
            for k in range(int(largo / 3)):
                nx = px + rng.uniform(-1.2, 1.2) + math.sin(k * 0.4) * 0.6
                ny = py + 3
                d.line([(px, py), (nx, ny)], fill=int(rng.integers(14, 26)))
                if rng.random() < 0.12:   # raicita
                    d.line([(nx, ny), (nx + rng.uniform(-6, 6), ny + rng.uniform(3, 8))], fill=20)
                px, py = nx, ny


def helechos(d, x0, x1):
    """Helechos y hierbas a contraluz en la boca de la cueva."""
    for k in range(9):
        bx = x0 + k * (x1 - x0) / 9 + rng.uniform(-3, 3)
        for h in range(5):
            ang = math.pi * (0.55 + 0.1 * (h - 2)) + rng.uniform(-0.1, 0.1)
            largo = rng.uniform(16, 34)
            d.line([(bx, PISO), (bx + math.cos(ang) * largo, PISO - math.sin(ang) * largo)], fill=8)
    for k in range(6):   # enredaderas que cuelgan de la entrada
        x = rng.uniform(2, 60)
        d.line([(x, 20), (x + rng.uniform(-4, 4), 20 + rng.uniform(40, 110))], fill=12)


def mural(d, x0, y0):
    """Gran pared pintada por los antepasados: procesión, nahui ollin, sol y venados."""
    tono = 118
    # nahui ollin grande
    cx, cy = x0 + 40, y0 + 24
    for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        d.line([(cx, cy), (cx + dx * 20, cy + dy * 20)], fill=tono, width=2)
        d.ellipse([cx + dx * 20 - 5, cy + dy * 20 - 5, cx + dx * 20 + 5, cy + dy * 20 + 5], outline=tono)
    d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], outline=tono)
    d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=tono)
    # sol
    sx, sy = x0 + 200, y0 + 4
    d.ellipse([sx - 9, sy - 9, sx + 9, sy + 9], outline=tono)
    for k in range(12):
        a = k * math.pi / 6
        d.line([(sx + math.cos(a) * 12, sy + math.sin(a) * 12), (sx + math.cos(a) * 17, sy + math.sin(a) * 17)], fill=tono)
    # procesión de personas tomadas de la mano hacia una casa (el camino de las ánimas)
    for k in range(11):
        px = x0 + 80 + k * 12
        py = y0 + 46 + int(2 * math.sin(k))
        d.ellipse([px - 2, py - 13, px + 2, py - 9], outline=tono)
        d.line([(px, py - 9), (px, py)], fill=tono)
        d.line([(px - 6, py - 6), (px + 6, py - 6)], fill=tono)
        d.line([(px, py), (px - 3, py + 7)], fill=tono)
        d.line([(px, py), (px + 3, py + 7)], fill=tono)
    hx, hy = x0 + 225, y0 + 40
    d.polygon([(hx - 10, hy), (hx + 10, hy), (hx, hy - 10)], outline=tono)
    d.rectangle([hx - 8, hy, hx + 8, hy + 14], outline=tono)
    # camino punteado (pétalos) de la procesión a la casa
    for k in range(12):
        d.point((x0 + 70 + k * 13, y0 + 60), fill=tono + 30)
    # venados y manos
    for vx in (x0 + 20, x0 + 150):
        vy = y0 + 84
        d.line([(vx, vy), (vx + 16, vy)], fill=tono)
        for lx in (vx + 1, vx + 15):
            d.line([(lx, vy), (lx, vy + 8)], fill=tono)
        d.line([(vx + 16, vy), (vx + 20, vy - 7)], fill=tono)
        d.line([(vx + 20, vy - 7), (vx + 17, vy - 13)], fill=tono)
        d.line([(vx + 20, vy - 7), (vx + 25, vy - 13)], fill=tono)
    for mx in (x0 + 100, x0 + 118, x0 + 250):
        my = y0 + 80
        d.ellipse([mx - 4, my - 2, mx + 4, my + 7], fill=tono - 30)
        for f in range(4):
            d.line([(mx - 3 + f * 2, my - 1), (mx - 4 + f * 2.6, my - 7)], fill=tono - 30)


def repisa(d, x0, y0):
    """Repisa de roca con cántaros, velas viejas y calaveras: ofrendas que alguien dejó hace mucho."""
    d.polygon([(x0 - 8, y0), (x0 + 120, y0 - 3), (x0 + 128, y0 + 6), (x0 + 100, y0 + 14), (x0, y0 + 12)], fill=20)
    d.line([(x0 - 8, y0), (x0 + 120, y0 - 3)], fill=62)
    for k, tipo in enumerate(("cantaro", "calavera", "vela", "cantaro", "calavera", "calavera", "vela")):
        x = x0 + 6 + k * 16
        y = y0 - 1
        if tipo == "cantaro":
            d.ellipse([x - 6, y - 14, x + 6, y], fill=34)
            d.rectangle([x - 3, y - 18, x + 3, y - 12], fill=34)
            d.arc([x - 6, y - 14, x + 6, y], 160, 250, fill=70)
        elif tipo == "calavera":
            d.ellipse([x - 5, y - 11, x + 5, y - 2], fill=120)
            d.rectangle([x - 3, y - 3, x + 3, y], fill=120)
            d.point((x - 2, y - 6), fill=10)
            d.point((x + 2, y - 6), fill=10)
            d.point((x, y - 3), fill=40)
        else:
            d.rectangle([x - 1, y - 12, x + 1, y], fill=90)
            d.line([(x, y - 13), (x, y - 15)], fill=40)


def petroglifos(d, x0, y0):
    """Grabados en la roca: espiral, nahui ollin, personas, venado, manos."""
    tono = 92
    tipo = int(rng.integers(0, 4))
    # espiral
    pts = []
    for i in range(60):
        a = i * 0.35
        r = 1.5 + i * 0.28
        pts.append((x0 + math.cos(a) * r, y0 + math.sin(a) * r))
    d.line(pts, fill=tono)
    # nahui ollin (las cuatro direcciones)
    cx, cy = x0 + 38, y0 + 4
    for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        d.line([(cx, cy), (cx + dx * 9, cy + dy * 9)], fill=tono)
        d.ellipse([cx + dx * 9 - 2, cy + dy * 9 - 2, cx + dx * 9 + 2, cy + dy * 9 + 2], outline=tono)
    d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], outline=tono)
    # personas tomadas de la mano
    for k in range(2 + tipo % 2):
        px = x0 - 6 + k * 10
        py = y0 + 30
        d.ellipse([px - 2, py - 12, px + 2, py - 8], outline=tono)
        d.line([(px, py - 8), (px, py)], fill=tono)
        d.line([(px - 5, py - 5), (px + 5, py - 5)], fill=tono)
        d.line([(px, py), (px - 3, py + 6)], fill=tono)
        d.line([(px, py), (px + 3, py + 6)], fill=tono)
    if tipo >= 2:   # venado
        vx, vy = x0 + 60, y0 + 28
        d.line([(vx, vy), (vx + 14, vy)], fill=tono)
        for lx in (vx + 1, vx + 13):
            d.line([(lx, vy), (lx, vy + 7)], fill=tono)
        d.line([(vx + 14, vy), (vx + 18, vy - 6)], fill=tono)
        d.line([(vx + 18, vy - 6), (vx + 16, vy - 11)], fill=tono)
        d.line([(vx + 18, vy - 6), (vx + 22, vy - 11)], fill=tono)


# =====================================================================
# Balero (juguete de madera que el abuelo talló)
# =====================================================================
BALERO = [
    "......kkkk......",
    ".....khhlmk.....",
    "....khwhllmk....",
    "....khhlllmk....",
    "....kdkkkkdk....",
    "....khlllllk....",
    ".....kmmmmk.....",
    ".......kk.......",
    ".......kk...k...",
    ".......kk..k.k..",
    ".......kk.k...k.",
    ".......kkk.....k",
    "......khlk.....k",
    "......khlk....k.",
    "......khlk...k..",
    "......khlk..k...",
    "......khlkkk....",
    "......khlk......",
    "......khlk......",
    "......khlk......",
    "......kmmk......",
    ".......kk.......",
]
TONO = {"k": 18, "d": 60, "m": 110, "l": 160, "h": 205, "w": 245}


def balero():
    alto, ancho = len(BALERO), len(BALERO[0])
    img = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
    for y, fila in enumerate(BALERO):
        for x, c in enumerate(fila):
            if c in TONO:
                t = TONO[c]
                img.putpixel((x, y), (t, t, t, 255))
    return img


# =====================================================================
# Recuerdos (teatro de sombras): fondo claro como luz de vela, figuras negras
# =====================================================================
RW, RH = 384, 216
SUELO = 176


def figura(nombre, alto, voltear=False, oscuro=True):
    if nombre == "xochik":
        im = Image.open(os.path.join(RAIZ, "assets/xochitl/xochik_idle.png")).convert("RGBA")
    else:
        im = Image.open(os.path.join(RAIZ, "assets/pueblo/%s.png" % nombre)).convert("RGBA")
    im = im.crop(im.getbbox())
    esc = alto / im.height
    im = im.resize((max(1, int(im.width * esc)), alto), Image.NEAREST if nombre != "xochik" else Image.BILINEAR)
    if voltear:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    a = np.asarray(im)[..., 3]
    a = np.where(a > 100, 255, 0).astype(np.uint8)
    if oscuro:
        sil = Image.new("RGBA", im.size, (12, 12, 12, 0))
        sil.putalpha(Image.fromarray(a))
        return sil
    im.putalpha(Image.fromarray(np.minimum(a, np.asarray(im)[..., 3])))
    return im


def poner(lienzo, fig, x, pie_y=SUELO):
    lienzo.alpha_composite(fig, (int(x - fig.width / 2), int(pie_y - fig.height)))


def fondo_recuerdo(oscuro=False, semilla=0):
    yy, xx = np.mgrid[0:RH, 0:RW]
    d = np.sqrt(((xx - RW * 0.5) / (RW * 0.62)) ** 2 + ((yy - RH * 0.45) / (RH * 0.7)) ** 2)
    if oscuro:
        v = 0.16 - 0.10 * np.clip(d, 0, 1)
    else:
        v = 0.86 - 0.55 * np.clip(d, 0, 1) ** 1.4
    v += 0.04 * (fractal(RW, RH, 12, 40 + semilla, 2) - 0.5)
    v[SUELO:, :] *= 0.82
    img = Image.fromarray((np.clip(v, 0, 1) * 255).astype(np.uint8), "L").convert("RGBA")
    return img


def flama(lienzo, x, y, tam=1.0, apagada=False):
    d = ImageDraw.Draw(lienzo)
    if apagada:
        for i in range(14):
            d.point((x + int(3 * math.sin(i * 0.8)), y - 4 - i * 2), fill=(90, 90, 90, 200))
        return
    brillo = Image.new("RGBA", lienzo.size, (0, 0, 0, 0))
    db = ImageDraw.Draw(brillo)
    r = int(26 * tam)
    db.ellipse([x - r, y - r - 4, x + r, y + r - 4], fill=(255, 255, 255, 110))
    brillo = brillo.filter(ImageFilter.GaussianBlur(9))
    lienzo.alpha_composite(brillo)
    d.polygon([(x - 3 * tam, y), (x + 3 * tam, y), (x, y - 9 * tam)], fill=(255, 255, 255, 255))


def vela(lienzo, x, base_y, apagada=False):
    d = ImageDraw.Draw(lienzo)
    d.rectangle([x - 3, base_y - 16, x + 3, base_y], fill=(12, 12, 12, 255))
    d.line([(x, base_y - 16), (x, base_y - 19)], fill=(12, 12, 12, 255))
    flama(lienzo, x, base_y - 19, 1.0, apagada)


def balero_sombra(d, x, y, bola_dx=0, bola_dy=0):
    d.line([(x, y), (x, y + 14)], fill=(12, 12, 12, 255), width=2)
    d.ellipse([x - 5, y - 6, x + 5, y + 1], fill=(12, 12, 12, 255))
    if bola_dx or bola_dy:
        d.line([(x, y + 6), (x + bola_dx, y + bola_dy)], fill=(40, 40, 40, 255))
        d.ellipse([x + bola_dx - 4, y + bola_dy - 4, x + bola_dx + 4, y + bola_dy + 4], fill=(12, 12, 12, 255))


def guirnalda(d, y=8):
    """Papel picado colgando arriba (siluetas)."""
    d.line([(0, y), (RW, y + 4)], fill=(12, 12, 12, 255))
    for i in range(0, RW, 26):
        yy = y + int(i * 4 / RW)
        d.polygon([(i + 2, yy), (i + 22, yy), (i + 22, yy + 16), (i + 17, yy + 20), (i + 12, yy + 16),
                   (i + 7, yy + 20), (i + 2, yy + 16)], fill=(12, 12, 12, 255))
        d.rectangle([i + 8, yy + 5, i + 10, yy + 7], fill=(0, 0, 0, 0))
        d.rectangle([i + 14, yy + 5, i + 16, yy + 7], fill=(0, 0, 0, 0))
        d.rectangle([i + 11, yy + 10, i + 13, yy + 12], fill=(0, 0, 0, 0))


def cama(d, x, ancho=150):
    negro = (12, 12, 12, 255)
    d.rectangle([x, SUELO - 34, x + ancho, SUELO - 24], fill=negro)       # colchón
    d.rectangle([x - 4, SUELO - 56, x + 4, SUELO], fill=negro)            # cabecera
    d.rectangle([x + ancho - 4, SUELO - 40, x + ancho + 2, SUELO], fill=negro)
    d.rectangle([x + 8, SUELO - 24, x + 12, SUELO], fill=negro)
    d.rectangle([x + ancho - 14, SUELO - 24, x + ancho - 10, SUELO], fill=negro)


def sombrero(d, x, y):
    negro = (12, 12, 12, 255)
    d.ellipse([x - 16, y - 3, x + 16, y + 3], fill=negro)
    d.rectangle([x - 7, y - 11, x + 7, y], fill=negro)


def altar(d, x):
    negro = (12, 12, 12, 255)
    d.rectangle([x - 70, SUELO - 40, x + 70, SUELO - 34], fill=negro)     # mesa
    d.rectangle([x - 66, SUELO - 34, x - 60, SUELO], fill=negro)
    d.rectangle([x + 60, SUELO - 34, x + 66, SUELO], fill=negro)
    d.rectangle([x - 45, SUELO - 62, x + 45, SUELO - 57], fill=negro)     # segundo nivel
    d.rectangle([x - 42, SUELO - 57, x - 38, SUELO - 40], fill=negro)
    d.rectangle([x + 38, SUELO - 57, x + 42, SUELO - 40], fill=negro)
    # arco de flores sobre el altar
    for i in range(23):
        a = math.pi * i / 22
        fx = x + math.cos(a) * 80
        fy = SUELO - 40 - math.sin(a) * 95
        d.ellipse([fx - 5, fy - 5, fx + 5, fy + 5], fill=negro)


def cruz(d, x):
    negro = (12, 12, 12, 255)
    d.rectangle([x - 3, SUELO - 70, x + 3, SUELO], fill=negro)
    d.rectangle([x - 18, SUELO - 56, x + 18, SUELO - 50], fill=negro)
    d.polygon([(x - 30, SUELO), (x + 30, SUELO), (x + 22, SUELO - 10), (x - 22, SUELO - 10)], fill=negro)
    for k in range(-3, 4):
        d.ellipse([x + k * 8 - 4, SUELO - 18, x + k * 8 + 4, SUELO - 10], fill=negro)


def arco_xantolo(lienzo, x, alto=150):
    im = Image.open(os.path.join(RAIZ, "assets/sierra/arco_xantolo.png")).convert("RGBA")
    im = im.crop(im.getbbox())
    esc = alto / im.height
    im = im.resize((int(im.width * esc), alto), Image.NEAREST)
    a = np.where(np.asarray(im)[..., 3] > 100, 255, 0).astype(np.uint8)
    sil = Image.new("RGBA", im.size, (12, 12, 12, 0))
    sil.putalpha(Image.fromarray(a))
    poner(lienzo, sil, x)


def terminar(lienzo):
    """Viñeta, grano y escalado x3."""
    v = np.asarray(lienzo.convert("L"), np.float32) / 255.0
    yy, xx = np.mgrid[0:RH, 0:RW]
    d = np.sqrt(((xx - RW / 2) / (RW / 2)) ** 2 + ((yy - RH / 2) / (RH / 2)) ** 2)
    v *= np.clip(1.15 - 0.55 * d ** 2, 0.25, 1)
    v += (rng.random(v.shape) - 0.5) * 0.06
    v = tramar(np.clip(v, 0, 1), np.linspace(0, 1, 14))
    img = Image.fromarray((v * 255).astype(np.uint8), "L")
    return img.resize((RW * 3, RH * 3), Image.NEAREST)


def recuerdos():
    r = {}
    abuelo = figura("anima_abuelo", 118)
    abuelo_izq = figura("anima_abuelo", 118, voltear=True)
    xochik = figura("xochik", 74)
    xochik_izq = figura("xochik", 74, voltear=True)

    # --- 1. El balero: el abuelo se lo regala y le enseña a jugar ---
    c = fondo_recuerdo(semilla=1)
    poner(c, abuelo, 150)
    poner(c, xochik_izq, 222)
    balero_sombra(ImageDraw.Draw(c), 190, 100)
    r["1_a"] = c
    c = fondo_recuerdo(semilla=2)
    poner(c, abuelo, 120)
    poner(c, xochik, 236)
    d = ImageDraw.Draw(c)
    balero_sombra(d, 250, 112, 10, -34)
    for i in range(7):   # el arco de la bolita
        a = math.pi * (0.15 + 0.11 * i)
        d.point((250 + int(math.cos(a) * 26), 112 - int(math.sin(a) * 34)), fill=(40, 40, 40, 255))
    r["1_b"] = c
    c = fondo_recuerdo(semilla=3)
    guirnalda(ImageDraw.Draw(c))
    arco_xantolo(c, 192, 160)
    poner(c, abuelo_izq, 176)
    poner(c, xochik_izq, 210)
    vela(c, 60, SUELO)
    vela(c, 330, SUELO)
    r["1_c"] = c

    # --- 2. La foto: el abuelo enfermo… y luego la cama vacía ---
    c = fondo_recuerdo(semilla=4)
    d = ImageDraw.Draw(c)
    cama(d, 110)
    acostado = abuelo.rotate(90, expand=True)
    c.alpha_composite(acostado, (118, SUELO - 34 - acostado.height + 8))
    poner(c, xochik_izq, 300)
    vela(c, 80, SUELO - 40)
    d.rectangle([66, SUELO - 40, 94, SUELO], fill=(12, 12, 12, 255))
    r["2_a"] = c
    c = fondo_recuerdo(semilla=5)
    d = ImageDraw.Draw(c)
    cama(d, 110)
    sombrero(d, 130, SUELO - 38)
    balero_sombra(d, 200, SUELO - 50)
    d.rectangle([66, SUELO - 40, 94, SUELO], fill=(12, 12, 12, 255))
    vela(c, 80, SUELO - 40, apagada=True)
    r["2_b"] = c
    c = fondo_recuerdo(semilla=6)
    d = ImageDraw.Draw(c)
    cruz(d, 196)
    poner(c, figura("abuelita", 104), 92)
    poner(c, figura("familia_mama", 108), 126)
    poner(c, figura("familia_papa", 112), 60)
    poner(c, xochik, 330)
    r["2_c"] = c

    # --- 3. La vela: este Xantolo, Xochik apagó la luz del abuelo ---
    c = fondo_recuerdo(semilla=7)
    d = ImageDraw.Draw(c)
    guirnalda(d)
    altar(d, 200)
    d.rectangle([188, SUELO - 84, 212, SUELO - 62], fill=(12, 12, 12, 255))   # retrato
    d.rectangle([192, SUELO - 80, 208, SUELO - 66], fill=(150, 150, 150, 255))
    vela(c, 230, SUELO - 62)
    poner(c, figura("abuelita", 104, voltear=True), 104)
    poner(c, xochik_izq, 320)
    r["3_a"] = c
    c = fondo_recuerdo(semilla=8)
    d = ImageDraw.Draw(c)
    guirnalda(d)
    altar(d, 200)
    d.rectangle([186, SUELO - 66, 214, SUELO - 62], fill=(12, 12, 12, 255))   # retrato boca abajo
    vela(c, 230, SUELO - 62, apagada=True)
    poner(c, xochik_izq, 262)
    for k in range(3):   # el soplido
        d.line([(246 - k * 2, SUELO - 86 + k * 5), (238 - k * 2, SUELO - 84 + k * 5)], fill=(40, 40, 40, 255))
    r["3_b"] = c
    c = fondo_recuerdo(oscuro=True, semilla=9)
    arco_xantolo(c, 192, 160)
    for nombre, x, alfa in (("anima_abuelo", 70, 200), ("anima_mujer", 300, 120), ("anima_hombre", 345, 90)):
        f = figura(nombre, 104, voltear=x > 192, oscuro=False)
        arr = np.asarray(f).copy()
        arr[..., 3] = (arr[..., 3].astype(np.float32) * alfa / 255).astype(np.uint8)
        poner(c, Image.fromarray(arr), x)
    r["3_c"] = c

    return {k: terminar(v) for k, v in r.items()}


def main():
    destino = sys.argv[1] if len(sys.argv) > 1 else os.path.join(RAIZ, "assets/cueva")
    os.makedirs(destino, exist_ok=True)
    tira = fondo_cueva().resize((W * 2, H * 2), Image.NEAREST)
    tira.crop((0, 0, 1152, 648)).save(os.path.join(destino, "cueva_1.png"))
    tira.crop((1152, 0, 2304, 648)).save(os.path.join(destino, "cueva_2.png"))
    b = balero()
    b.resize((b.width * 12, b.height * 12), Image.NEAREST).save(os.path.join(destino, "balero.png"))
    for k, img in recuerdos().items():
        img.save(os.path.join(destino, "recuerdo_%s.png" % k))
    print("ok cueva ->", destino)


if __name__ == "__main__":
    main()
