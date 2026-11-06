"""Talismanes: amuleto bordado (motivo nahui ollin) y manos de ánimas de la trampa espiritual.
Uso: python gen_talismanes.py <raíz del proyecto>
"""
import os
import sys
import numpy as np
from PIL import Image, ImageFilter

RAIZ = sys.argv[1] if len(sys.argv) > 1 else ".."
OUT = os.path.join(RAIZ, "assets", "talismanes")
os.makedirs(OUT, exist_ok=True)
PX = 2


def imagen(v, a):
    g = (np.clip(v, 0, 1) * 255).astype(np.uint8)
    al = (np.clip(a, 0, 1) * 255).astype(np.uint8)
    im = Image.fromarray(np.dstack([g, g, g, al]), "RGBA")
    return im.resize((im.width * PX, im.height * PX), Image.NEAREST)


def amuleto():
    """Bolsita de manta bordada con el nahui ollin (cuatro movimientos) y un cordón."""
    n = 28
    v = np.zeros((n + 8, n))
    a = np.zeros((n + 8, n))
    y0 = 8
    v[y0:, 2:n - 2] = 0.82          # tela de manta
    a[y0:, 2:n - 2] = 1
    v[y0:, 2] = v[y0:, n - 3] = 0.5  # orillas
    v[-1, 2:n - 2] = 0.5
    v[y0, 2:n - 2] = 0.6
    cx, cy = n / 2 - 0.5, y0 + (n - y0 + 8) / 2 - 1
    # Nahui ollin: cuatro lóbulos en aspa alrededor de un ojo central
    for ang in (np.pi / 4, 3 * np.pi / 4, 5 * np.pi / 4, 7 * np.pi / 4):
        for r in np.linspace(2, 8, 30):
            x = cx + np.cos(ang) * r
            y = cy + np.sin(ang) * r
            for dx in (-1, 0, 1):
                xi, yi = int(round(x + dx * np.sin(ang))), int(round(y - dx * np.cos(ang)))
                if 0 <= yi < v.shape[0] and 0 <= xi < n:
                    v[yi, xi] = 0.15
    for yy in range(v.shape[0]):
        for xx in range(n):
            d = np.hypot(xx - cx, yy - cy)
            if d < 2.6:
                v[yy, xx] = 0.15 if d > 1.2 else 0.95
    for k in range(2, n - 2, 2):     # punto de cruz en la orilla
        v[y0 + 2, k] = 0.3
        v[-3, k] = 0.3
    # Cordón
    for t in np.linspace(0, 1, 40):
        x = 4 + t * (n - 9)
        y = y0 - np.sin(t * np.pi) * 7
        v[int(y), int(x)] = 0.35
        a[int(y), int(x)] = 1
    imagen(v, a).save(os.path.join(OUT, "amuleto.png"))


def manos():
    """Manos pálidas de ánimas saliendo del suelo (2 cuadros: se abren y se cierran)."""
    rng = np.random.default_rng(4)
    W, H = 48, 80
    cuadros = []
    bases = [(10, 0.85), (25, 1.0), (39, 0.9)]
    for c in range(2):
        v = np.zeros((H, W))
        a = np.zeros((H, W))
        for i, (bx, esc) in enumerate(bases):
            alto = int(H * 0.75 * esc) - (6 if (i + c) % 2 else 0)
            inc = (0.12 if (i + c) % 2 else -0.08)
            # Brazo
            for k in range(alto):
                y = H - 1 - k
                x = bx + inc * k
                for w in range(-3, 4):
                    xi = int(round(x + w))
                    if 0 <= xi < W:
                        v[y, xi] = 0.85 - abs(w) * 0.07
                        a[y, xi] = 0.25 + 0.75 * (k / alto)
            # Palma y dedos abiertos/cerrados
            px, py = bx + inc * alto, H - alto
            apertura = 0.42 if (i + c) % 2 else 0.2
            for f in range(5):
                ang = -np.pi / 2 + (f - 2) * apertura
                largo = (7 if f == 0 or f == 4 else 11)
                for r in range(largo):
                    xi = int(round(px + np.cos(ang) * r))
                    yi = int(round(py + np.sin(ang) * r))
                    for dx in (0, 1):
                        if 0 <= xi + dx < W and 0 <= yi < H:
                            v[yi, xi + dx] = 0.92
                            a[yi, xi + dx] = 1
            for yy in range(int(py) - 2, int(py) + 6):
                for xx in range(int(px) - 4, int(px) + 5):
                    if 0 <= xx < W and 0 <= yy < H:
                        v[yy, xx] = 0.88
                        a[yy, xx] = 1
        im = imagen(v, a)
        halo = im.split()[3].filter(ImageFilter.GaussianBlur(4)).point(lambda p: int(p * 0.5))
        base = Image.new("RGBA", im.size, (255, 255, 255, 0))
        base.putalpha(halo)
        cuadros.append(Image.alpha_composite(base, im))
    tira = Image.new("RGBA", (cuadros[0].width * 2, cuadros[0].height))
    for i, cimg in enumerate(cuadros):
        tira.paste(cimg, (i * cimg.width, 0))
    tira.save(os.path.join(OUT, "manos_animas.png"))


if __name__ == "__main__":
    amuleto()
    manos()
    print("ok", sorted(os.listdir(OUT)))
