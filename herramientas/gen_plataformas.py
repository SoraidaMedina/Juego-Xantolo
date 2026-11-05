import numpy as np, sys
from PIL import Image
ESC = 4
def guardar(arr, alfa, ruta):
    rgb = (np.clip(arr, 0, 1) * 255).astype(np.uint8)
    a = (alfa * 255).astype(np.uint8)
    im = Image.fromarray(np.dstack([rgb, rgb, rgb, a]), "RGBA")
    im.resize((im.width * ESC, im.height * ESC), Image.NEAREST).save(ruta)

def roca(w, h, semilla, ruta):
    r = np.random.default_rng(semilla)
    v = np.zeros((h, w)); a = np.zeros((h, w))
    borde_sup = 2 + (np.sin(np.linspace(0, 3, w) * r.uniform(1, 2)) * 1.2).astype(int)
    for x in range(w):
        lado = min(x, w - 1 - x)
        y0 = borde_sup[x] + max(0, 3 - lado)
        y1 = h - max(0, 2 - lado)
        for y in range(y0, y1):
            t = (y - y0) / max(y1 - y0, 1)
            v[y, x] = 0.30 - t * 0.20 + r.uniform(-0.03, 0.03)
            a[y, x] = 1
        if y0 < h:
            v[y0, x] = 0.52 + r.uniform(-0.04, 0.04)   # canto iluminado por la luna
            if y0 + 1 < h: v[y0 + 1, x] = 0.40
    for _ in range(w // 3):  # grietas
        x, y = r.integers(2, w - 2), r.integers(4, h - 2)
        for k in range(r.integers(2, 4)):
            if a[min(y + k, h - 1), x]: v[min(y + k, h - 1), x] = 0.10
    guardar(v, a, ruta)

def tronco(w, h, ruta):
    r = np.random.default_rng(5)
    v = np.zeros((h, w)); a = np.zeros((h, w))
    for x in range(w):
        for y in range(1, h - 1):
            t = (y - 1) / (h - 3)
            v[y, x] = 0.30 - abs(t - 0.25) * 0.28 + (0.04 if (x + y * 3) % 7 == 0 else 0) + r.uniform(-0.02, 0.02)
            a[y, x] = 1
        v[1, x] = 0.48
    for x in range(0, w, 5):  # corteza
        for y in range(3, h - 2):
            if r.random() < 0.6: v[y, x + r.integers(0, 2) if x + 1 < w else x] = 0.12
    # corte del extremo con anillos
    cx, cy = w - 3, h // 2
    for y in range(h):
        for x in range(w - 6, w):
            d = np.hypot((x - cx) * 1.3, y - cy)
            if d <= h / 2 - 0.5:
                v[y, x] = 0.42 - (int(d) % 2) * 0.12; a[y, x] = 1
    # ramita
    for k in range(6):
        y, x = 1 - k // 2, 12 + k
        if 0 <= y < h: v[y, x] = 0.25; a[y, x] = 1
    guardar(v, a, ruta)

def piedra_rio(w, h, semilla, ruta):
    r = np.random.default_rng(semilla)
    v = np.zeros((h, w)); a = np.zeros((h, w))
    for y in range(h):
        for x in range(w):
            d = ((x - w / 2 + 0.5) / (w / 2)) ** 2 + ((y - h * 0.55) / (h * 0.55)) ** 2
            if d <= 1:
                v[y, x] = 0.40 - (y / h) * 0.25 + r.uniform(-0.03, 0.03); a[y, x] = 1
    v[a[:, :] > 0] += 0
    for x in range(w):  # canto mojado brillante
        ys = np.where(a[:, x] > 0)[0]
        if len(ys): v[ys[0], x] = 0.62
    for x in range(w):  # agua lamiendo la base
        v[h - 1, x] = 0.30 if x % 3 else 0.5; a[h - 1, x] = 0.7
    guardar(v, a, ruta)

out = sys.argv[1]
roca(30, 10, 1, out + "/roca_ancha.png")
roca(18, 9, 2, out + "/roca_chica.png")
tronco(42, 8, out + "/tronco.png")
piedra_rio(14, 7, 3, out + "/piedra_rio.png")
