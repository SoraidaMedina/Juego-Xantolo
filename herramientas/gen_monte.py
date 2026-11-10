"""Fondo del primer escenario del Monte del Nahual (nivel 3): la ladera, antes del valle de la cueva.

- assets/fondos/monte_1_ladera.png : montañas con niebla y una vereda, tomado de monte_nahual_bg.png.

Se dibuja a 396x168 y se escala x4 (1584x672, como monte.png). En el juego va a escala 0.844 justo a
la derecha de monte.png, así que 1 px de baja resolución = 3.376 px del juego y el piso (y=673.5)
queda en la fila 144. El borde izquierdo se funde con el risco del borde derecho de monte.png.
Uso: python gen_monte.py ../assets/fondos
"""
import sys
import numpy as np
from PIL import Image
import gen_fondos as gf

gf.W, gf.H, gf.ESC = 396, 168, 4
W, H = gf.W, gf.H
PISO = 144
ESC_JUEGO = 3.376
IZQ = 1350.4  # x del juego donde empieza este fondo
# Escalones de piedra para subir al risco desde la ladera (deben coincidir con Nivel3Monte.tscn):
# 6 escalones de 50 px de ancho y 47 de alto; el de más arriba queda al ras del risco (y=391.5)
ESCALON_ANCHO, ESCALON_ALTO, CIMA = 50.0, 47.0, 391.5
N_ESCALONES = 6
rng = np.random.default_rng(31)


def u(x_juego):
    return int(round((x_juego - IZQ) / ESC_JUEGO))


def quitar_luna(L, cx, cy, r, desde):
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.hypot(xx - cx, yy - cy)
    a = np.clip((r - d) / 6, 0, 1)
    copia = np.roll(L.v, cx - desde, axis=1)
    L.v = L.v * (1 - a) + copia * a


def matojo_seco(L, x, y, alto, color, semilla):
    """Arbusto seco de ramas, como los del valle del Nahual."""
    r = np.random.default_rng(semilla)
    for _ in range(9):
        ang = r.uniform(-2.5, -0.6)
        largo = alto * r.uniform(0.6, 1.0)
        px, py = x, y
        for i in range(int(largo)):
            px += np.cos(ang) * 1.0
            py += np.sin(ang) * 1.0
            ang += r.uniform(-0.25, 0.25)
            L.pix(px, py, color)


def fila(y_juego):
    return int(round((y_juego - 186.5) / ESC_JUEGO))


def laja(L, x0, x1, y_pie, r, grano, frente=4):
    """Laja de piedra como las escaleras del risco de monte.png: cara de arriba ovalada en gris medio,
    canto al frente con grietas y contorno oscuro. y_pie es donde se paran los pies (mitad de la cara)."""
    bloque = gf.ruido2d(H, W, 3.0, 81)
    cx = (x0 + x1) / 2
    ax = (x1 - x0) / 2
    arriba = 3.0                     # media altura de la cara ovalada (frente = alto del canto)
    for x in range(int(x0) - 1, int(x1) + 2):
        t = (x - cx) / (ax + 0.5)
        if abs(t) > 1:
            continue
        curva = np.sqrt(1 - t * t)
        y_top = y_pie - arriba * curva
        y_cara = y_pie + arriba * curva          # orilla de enfrente de la cara de arriba
        y_fin = y_cara + frente * (0.6 + 0.4 * curva)
        for y in range(int(np.floor(y_top)), int(np.ceil(y_fin)) + 1):
            if not (0 <= x < W and 0 <= y < H):
                continue
            if y <= y_cara:   # cara de arriba: gris medio, más clara al fondo (luz de luna)
                k = (y - y_top) / max(y_cara - y_top, 1)
                v = 0.33 - k * 0.06 + (grano[y, x] - 0.5) * 0.08
            else:             # canto: más oscuro hacia abajo, con textura de piedra
                k = (y - y_cara) / max(frente, 1)
                v = 0.21 - k * 0.06 + (grano[y, x] - 0.5) * 0.07 + (bloque[y, x] - 0.5) * 0.08
            L.v[y, x] = v
        # Contorno oscuro de la laja y línea entre cara y canto
        L.pix(x, np.floor(y_top) - 1, 0.10)
        L.pix(x, np.ceil(y_fin) + 1, 0.07)
        L.pix(x, round(y_cara) + 1, 0.20)
    for y in range(int(y_pie - arriba), int(y_pie + arriba + frente) + 1):
        L.pix(int(x0) - 2, y, 0.09)
        L.pix(int(x1) + 2, y, 0.09)
    # Grietas en la cara y el canto
    for _ in range(3):
        gx = r.integers(int(x0) + 2, int(x1) - 2)
        gy = int(y_pie) + r.integers(-2, 1)
        for _ in range(r.integers(2, 5)):
            L.pix(gx, gy, 0.16)
            gx += r.choice([-1, 1])
            gy += r.choice([0, 1])
    for _ in range(3):
        gx = r.integers(int(x0) + 2, int(x1) - 2)
        for y in range(int(y_pie + arriba) + 2, int(y_pie + arriba + frente)):
            L.pix(gx, y, 0.12)
            L.pix(gx + 1, y, min(L.v[y, min(gx + 1, W - 1)] + 0.05, 0.4))
            if r.random() < 0.25:
                gx += r.choice([-1, 1])


def escalones(L, vecino):
    """Escalones de lajas de piedra apiladas contra el risco, como las escaleras del otro lado.
    Debajo de las lajas, la roca del risco de monte.png en espejo (continúa sin costura)."""
    r = np.random.default_rng(91)
    grano = gf.ruido2d(H, W, 1.3, 78)
    tops = []
    for k in range(N_ESCALONES):
        tops.append((u(IZQ + ESCALON_ANCHO * k), u(IZQ + ESCALON_ANCHO * (k + 1)),
                     fila(CIMA + ESCALON_ALTO * k)))
    fin = tops[-1][1]
    # Roca del risco debajo de la escalera, más oscura hacia abajo
    for x0, x1, y0 in tops:
        for x in range(max(x0, 0), min(x1 + 1, W)):
            for y in range(y0, PISO + 3):
                prof = (y - y0) / max(PISO - y0, 1)
                L.v[y, x] = vecino[y, W - 1 - x] * (0.85 - prof * 0.3)
    # Lajas: de arriba hacia abajo, para que cada una quede encimada sobre la de atrás
    for i, (x0, x1, y0) in enumerate(tops):
        abajo = tops[i + 1][2] if i + 1 < len(tops) else PISO + 2
        laja(L, x0 - 3, x1 + 2, y0, r, grano, frente=abajo - y0 + 1)
        # Zacate en la orilla de atrás de la laja
        for x in range(x0, x1):
            if r.random() < 0.15:
                for h in range(r.integers(1, 3)):
                    L.pix(x, y0 - 4 - h, 0.22)
    # Piedras sueltas y helechos al pie
    for _ in range(10):
        L.disco(r.integers(0, fin + 4), PISO + r.integers(0, 3), r.uniform(1.0, 2.2), 0.20)
    for x in range(2, fin + 6, 9):
        L.helecho(x + r.integers(-2, 3), H - 1, int(r.integers(9, 14)), 0.07)


def ladera(base, vecino, ruta):
    L = gf.Lienzo()
    # Recorte de monte_nahual_bg: cerros con niebla y el árbol seco a la derecha
    im = Image.open(base).convert("L").crop((760, 120, 1670, 506)).resize((W, H), Image.BOX)
    L.v = np.asarray(im).astype(float) / 255.0 * 1.2 + 0.03  # más claro, como monte.png
    quitar_luna(L, 296, 33, 34, 225)
    L.niebla(PISO - 14, 9, 0.55, 0.30, semilla=7)
    # Matorrales secos y piedras detrás de la vereda
    for i, x in enumerate(range(4, W, 23)):
        matojo_seco(L, x + rng.integers(-5, 5), PISO - 1, int(rng.integers(8, 15)), 0.10, 200 + i)
    for x in (u(1900), u(2330)):
        L.disco(x, PISO - 3, 7, 0.16)
        L.disco(x - 3, PISO - 6, 4, 0.20)
    # Vereda: tierra apisonada, un poco más clara donde pega la luna
    tex = gf.ruido2d(H, W, 2.5, 8)
    perfil = (gf.ruido1d(W, 14, 9, 2) - 0.5) * 2.0
    for x in range(W):
        y0 = int(PISO + perfil[x])
        prof = np.arange(H - y0)
        L.v[y0:, x] = 0.13 - np.minimum(prof, 20) * 0.003 + (tex[y0:, x] - 0.5) * 0.06
        L.v[y0, x] = 0.22 + (tex[y0, x] - 0.5) * 0.05
    for _ in range(160):  # piedritas
        L.pix(rng.integers(0, W), rng.integers(PISO + 2, PISO + 9), 0.24)
    L.pasto(PISO, 4, 0.12, 0.8, semilla=10)
    # Helechos y zacate en primer plano
    for x in range(0, W, 10):
        L.helecho(x + rng.integers(-3, 3), H - 1, int(rng.integers(9, 15)), 0.06)
    L.pasto(H - 1, 7, 0.05, 0.9, semilla=11)
    L.vineta(0.2)
    # Borde izquierdo: se funde en espejo con el risco del borde derecho de monte.png
    for i in range(60):
        a = (1 - i / 60) ** 2
        L.v[:, i] = L.v[:, i] * (1 - a) + vecino[:, W - 1 - i] * a
    escalones(L, vecino)
    L.guardar(ruta)


if __name__ == "__main__":
    fondos = sys.argv[1]
    vecino = gf.base_original(fondos + "/monte.png")
    ladera(fondos + "/monte_nahual_bg.png", vecino, fondos + "/monte_1_ladera.png")
    print("ok")
