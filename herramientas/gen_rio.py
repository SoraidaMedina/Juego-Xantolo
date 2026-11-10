"""Fondos de los dos tramos nuevos del Río de la Llorona (nivel 2), a partir del fondo original.

- assets/fondos/rio_1_orilla.png   : la orilla, con un arroyo que se cruza por piedras.
- assets/fondos/rio_2_rapidos.png  : los rápidos, río ancho con un islote en medio.

Se dibuja a 334x188 y se escala x5 (1670x940, como rio_llorona_bg.png). En el juego cada fondo
se pone a escala 0.844, así que 1 px de baja resolución = 4.22 px del juego y el piso (y=752)
queda en la fila 162. El borde derecho de cada fondo se funde con el tramo vecino para que no
se note la costura al caminar.
- assets/objetos/rio_mata.png      : la mata de los escondites.
Uso: python gen_rio.py ../assets/fondos ../assets/objetos
"""
import sys
import numpy as np
import gen_fondos as gf

gf.W, gf.H, gf.ESC = 334, 188, 5
W, H = gf.W, gf.H
PISO = 162
ESC_JUEGO = 4.22                  # px del juego por px de baja resolución
IZQ_A, IZQ_B = -2814.7, -1405.2   # x del juego donde empieza cada fondo
rng = np.random.default_rng(23)


def u(x_juego, izq):
    return int(round((x_juego - izq) / ESC_JUEGO))


def quitar_luna(L, cx, cy, r, desde):
    """Tapa la luna copiando cielo de otra columna, con borde suave (una sola luna por tramo)."""
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.hypot(xx - cx, yy - cy)
    a = np.clip((r - d) / 6, 0, 1)
    copia = np.roll(L.v, cx - desde, axis=1)
    L.v = L.v * (1 - a) + copia * a


def matorrales(L, x0, x1, semilla):
    """Matas oscuras detrás de la orilla: rompen la línea recta del piso."""
    r = np.random.default_rng(semilla)
    x = x0 + 2
    while x < x1 - 2:
        rad = r.uniform(3, 7)
        L.disco(x, PISO - rad * 0.4, rad, 0.06 + r.uniform(0, 0.03))
        for _ in range(int(rad * 2)):  # hojas con luz de luna
            a = r.uniform(np.pi * 1.1, np.pi * 1.9)
            L.pix(x + np.cos(a) * rad * 0.8, PISO - rad * 0.4 + np.sin(a) * rad * 0.8, 0.13)
        x += rad * r.uniform(1.2, 2.2)


def tierra(L, x0, x1, semilla, borde_izq=True, borde_der=True):
    """Orilla de tierra; su superficie coincide con el piso del juego."""
    matorrales(L, x0, x1, semilla + 7)
    tex = gf.ruido2d(H, W, 2.5, semilla)
    perfil = (gf.ruido1d(W, 12, semilla, 2) - 0.5) * 2.0
    for x in range(max(x0, 0), min(x1, W)):
        y0 = int(PISO + perfil[x])
        # Las orillas bajan al agua en talud
        if borde_izq and x - x0 < 4:
            y0 += (4 - (x - x0)) * 2
        if borde_der and x1 - x < 4:
            y0 += (4 - (x1 - x)) * 2
        prof = np.arange(H - y0)
        L.v[y0:, x] = 0.10 - np.minimum(prof, 20) * 0.002 + (tex[y0:, x] - 0.5) * 0.06
        L.v[y0, x] = 0.15 + (tex[y0, x] - 0.5) * 0.06   # filo de la orilla, con luz de luna
    # Piedras sueltas en la tierra
    r = np.random.default_rng(semilla + 3)
    for _ in range(max((x1 - x0) // 6, 1)):
        px, py = r.integers(max(x0, 0) + 3, max(min(x1, W) - 3, max(x0, 0) + 4)), r.integers(PISO + 4, H - 3)
        L.disco(px, py, r.uniform(0.8, 1.8), 0.16)
    for x in range(max(x0, 0) + 2, min(x1, W) - 2, 2):
        h = int(rng.integers(1, 5))
        for i in range(h):
            L.pix(x + (i // 3) * rng.choice([-1, 1]), PISO - 1 - i, 0.12)


def agua(L, x0, x1, semilla):
    """Río en primer plano: oscuro, con reflejos de luna rotos por la corriente."""
    tex = gf.ruido2d(H, W, 3, semilla)
    r = np.random.default_rng(semilla)
    a, b = max(x0, 0), min(x1, W)
    sup = PISO + 3
    L.v[PISO - 2:sup, a:b] *= 0.75     # sombra del corte entre las orillas
    for y in range(sup, H):
        t = (y - sup) / (H - sup)
        L.v[y, a:b] = 0.13 - 0.05 * t + (tex[y, a:b] - 0.5) * 0.05
    # Reflejos: rayitas cortas que se alargan con la distancia
    for _ in range(int((x1 - x0) * 0.3)):
        x, y = r.integers(a + 1, b - 7), r.integers(sup + 2, H - 2)
        L.linea(x, y, x + r.integers(2, 7), y, 0.17 + r.random() * 0.10)
    # Espuma donde la corriente choca
    for x in range(a, b):
        if r.random() < 0.55:
            L.pix(x, sup + r.integers(0, 2), 0.32 + r.random() * 0.12)


def helechos(L, desde, hasta, evitar=()):
    for x in range(desde, hasta, 9):
        if any(a - 5 < x < b + 5 for a, b in evitar):
            continue
        L.helecho(x + rng.integers(-3, 3), H - 1, int(rng.integers(10, 17)), 0.04)


def fundir(L, vecino, ancho=60):
    """Funde el borde derecho con el inicio del fondo vecino, en espejo: en la costura coinciden
    pixel a pixel y, hacia dentro, se va quedando el dibujo propio."""
    for i in range(ancho):
        a = (1 - i / ancho) ** 2
        x = W - 1 - i
        L.v[:, x] = L.v[:, x] * (1 - a) + vecino[:, i] * a


def orilla(orig, vecino, ruta):
    """Tramo 1: la orilla. Arranca el nivel; un arroyo corto para aprender a saltar."""
    L = gf.Lienzo()
    # Otro encuadre del valle: más cerca de las montañas, la cascada y la luna
    L.v = gf.base_original(orig, voltear=True, recorte=(700, 0, 1670, 546))
    a0, a1 = u(-2050, IZQ_A), u(-1750, IZQ_A)
    L.niebla(150, 8, 0.45, 0.22, semilla=31)
    tierra(L, 0, a0, 41, borde_izq=False)
    agua(L, a0, a1, 42)
    tierra(L, a1, W, 43, borde_der=False)
    L.cruz_camino(u(-2440, IZQ_A), PISO - 1, 0.06)
    helechos(L, 0, W, evitar=[(a0, a1)])
    L.vineta(0.2)
    fundir(L, vecino)
    L.guardar(ruta)
    return L.v


def rapidos(orig, ruta):
    """Tramo 2: los rápidos. Río ancho con un islote; piedras fijas, que se mecen y que se hunden."""
    L = gf.Lienzo()
    # El valle visto al revés: el sauce queda a la derecha y continúa en el tramo de la Llorona
    L.v = gf.base_original(orig, voltear=True, recorte=(300, 0, 1670, 772))
    quitar_luna(L, 120, 43, 26, 45)
    r0, r1 = u(-1150, IZQ_B), u(-250, IZQ_B)
    i0, i1 = u(-720, IZQ_B), u(-620, IZQ_B)
    L.niebla(152, 6, 0.35, 0.24, semilla=51)
    tierra(L, 0, r0, 52, borde_izq=False)
    agua(L, r0, r1, 53)
    tierra(L, i0, i1, 54)
    L.cruz_camino((i0 + i1) // 2 + 3, PISO - 1, 0.06)
    tierra(L, r1, W, 55, borde_der=False)
    helechos(L, 0, W, evitar=[(r0, r1)])
    L.vineta(0.15)
    fundir(L, gf.base_original(orig))
    L.guardar(ruta)
    return L.v




def mata(ruta):
    """Arbusto de la orilla (escondite): mata redonda de hojas, iluminada por la luna desde arriba.
    Va delante de Xochik (z_index) para que se vea que, agachada, queda oculta."""
    from PIL import Image
    w, h, esc = 28, 19, 4
    r = np.random.default_rng(5)
    v = np.zeros((h, w))
    a = np.zeros((h, w))
    yy, xx = np.mgrid[0:h, 0:w]
    for cx, cy, rad in [(7, 12, 6.5), (14, 9, 8), (21, 12, 6.5), (11, 14, 5.5), (18, 14, 5.5), (14, 15, 6)]:
        d = np.hypot(xx - cx, (yy - cy) * 1.1)
        dentro = d <= rad
        luz = np.clip((cy - yy) / rad, -1, 1) * 0.06      # arriba más claro
        val = 0.14 + luz * 1.5 + r.uniform(-0.01, 0.01)
        v[dentro] = np.maximum(v[dentro], val[dentro])
        a[dentro] = 1
    # Textura de hojas: cada hoja es un puntito con su lado de luz arriba y sombra abajo
    for _ in range(160):
        x, y = r.integers(1, w - 1), r.integers(1, h - 1)
        if a[y, x]:
            v[y, x] += 0.07 * (1 - y / h) + 0.02
            if y + 1 < h and a[y + 1, x]:
                v[y + 1, x] -= 0.03
    # Hojas que sobresalen del contorno, más claras arriba (luz de luna)
    borde = [(x, y) for y in range(1, h - 1) for x in range(1, w - 1)
             if a[y, x] and (not a[y - 1, x] or not a[y, x - 1] or not a[y, x + 1])]
    for x, y in borde:
        if r.random() < 0.45:
            dx, dy = (0, -1) if not a[y - 1, x] else ((-1, 0) if not a[y, x - 1] else (1, 0))
            a[y + dy, x + dx] = 1
            v[y + dy, x + dx] = 0.20 + 0.10 * (1 - y / h)
        v[y, x] += 0.05 * (1 - y / h)
    v[h - 2:, :] *= 0.7  # sombra al pie
    umbral = np.tile(gf.BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]
    q = np.floor(np.clip(v, 0, 1) * 24 + umbral) / 24
    img = np.zeros((h, w, 4), np.uint8)
    img[..., :3] = (np.clip(q, 0, 1) * 255).astype(np.uint8)[..., None]
    img[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(img, "RGBA").resize((w * esc, h * esc), Image.NEAREST).save(ruta)


if __name__ == "__main__":
    fondos, objetos = sys.argv[1], sys.argv[2]
    orig = fondos + "/rio_llorona_bg.png"
    v_b = rapidos(orig, fondos + "/rio_2_rapidos.png")
    orilla(orig, v_b, fondos + "/rio_1_orilla.png")
    mata(objetos + "/rio_mata.png")
    print("ok")
