"""Arte de la Sierra v3 (nítido): fondos a resolución completa + sprites del arco, rocas y piedras.

Todo lo nuevo se dibuja en una cuadrícula de 2x (cada "pixel" = 2x2 px reales) y se pega
sobre el fondo original sin reescalarlo, así no se pierde detalle.
Uso: python gen_sierra.py <raíz del proyecto>
"""
import os
import sys
import numpy as np
from PIL import Image

PX = 2
ESC_FONDO = 0.844
SUELO = int(560 / ESC_FONDO / PX)  # la vereda del juego (y=560) en la cuadrícula 2x


def gx(x_juego):
    """x del juego (px dentro de la pantalla) -> columna de la cuadrícula 2x del fondo."""
    return int(x_juego / ESC_FONDO / PX)
RAIZ = sys.argv[1] if len(sys.argv) > 1 else ".."
FONDOS = os.path.join(RAIZ, "assets", "fondos")
SPR = os.path.join(RAIZ, "assets", "sierra")
os.makedirs(SPR, exist_ok=True)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5


def ruido2d(h, w, escala, semilla):
    r = np.random.default_rng(semilla)
    g = r.random((int(h / escala) + 3, int(w / escala) + 3))
    ys, xs = np.arange(h)[:, None] / escala, np.arange(w)[None, :] / escala
    iy, ix = ys.astype(int), xs.astype(int)
    fy, fx = ys - iy, xs - ix
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a = g[iy, ix] * (1 - fx) + g[iy, ix + 1] * fx
    b = g[iy + 1, ix] * (1 - fx) + g[iy + 1, ix + 1] * fx
    return a * (1 - fy) + b * fy


class Capa:
    """Lienzo en escala de grises con transparencia (valor + alfa)."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.v = np.zeros((h, w))
        self.a = np.zeros((h, w))

    def pix(self, x, y, c, a=1.0):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.v[y, x] = c
            self.a[y, x] = max(self.a[y, x], a)

    def disco(self, cx, cy, r, c, a=1.0):
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.3:
                    self.pix(x, y, c, a)

    def linea(self, x0, y0, x1, y1, c, grosor=1, a=1.0):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / max(n, 1)
            for g in range(grosor):
                self.pix(x0 + (x1 - x0) * t + g, y0 + (y1 - y0) * t, c, a)

    def imagen(self, tramado=True):
        v = np.clip(self.v, 0, 1)
        if tramado:
            u = np.tile(BAYER, (self.h // 4 + 1, self.w // 4 + 1))[: self.h, : self.w]
            v = np.clip(np.round(v * 32 + u) / 32, 0, 1)
        g = (v * 255).astype(np.uint8)
        al = (np.clip(self.a, 0, 1) * 255).astype(np.uint8)
        im = Image.fromarray(np.dstack([g, g, g, al]), "RGBA")
        return im.resize((self.w * PX, self.h * PX), Image.NEAREST)


# ---------------------------------------------------------------- flores
def cempasuchil(C, x, y, r, brillo, rng):
    """Flor de cempasúchil: pompón de pétalos rizados, iluminado desde arriba a la izquierda."""
    for yy in range(int(y - r) - 1, int(y + r) + 2):
        for xx in range(int(x - r) - 1, int(x + r) + 2):
            d = np.hypot(xx - x, yy - y)
            ang = np.arctan2(yy - y, xx - x)
            borde = r * (0.9 + 0.1 * np.sin(ang * 7 + x))  # orilla rizada
            if d <= borde:
                luz = -0.14 * ((xx - x) + (yy - y)) / (r + 0.01) - 0.18 * (d / r) ** 2
                anillo = -0.07 if (int(d * 1.3 + ang * 2) % 2 == 0 and d > r * 0.35) else 0.0
                C.pix(xx, yy, brillo + luz + anillo + rng.uniform(-0.03, 0.03))
    C.pix(x - r * 0.3, y - r * 0.3, min(brillo + 0.18, 1))


def mano_de_leon(C, x, y, r, brillo, rng):
    """Mano de león (terciopelo): cresta ondulada, más oscura que el cempasúchil."""
    for k in range(int(r * 2.4)):
        t = k / (r * 2.4)
        cx = x - r + t * 2 * r
        alto = r * (0.6 + 0.4 * np.sin(t * np.pi)) * (0.8 + 0.2 * np.sin(t * 17))
        for j in range(int(alto) + 1):
            sombra = -0.1 * j / max(alto, 1)
            C.pix(cx, y + r * 0.4 - j, brillo + sombra + (0.08 if j == int(alto) else 0))


def hoja_palma(C, x, y, largo, ang, c, rng):
    """Palmilla: hoja en abanico, ancha al centro, con nervadura clara."""
    for i in range(int(largo)):
        t = i / largo
        px = x + np.cos(ang) * i
        py = y + np.sin(ang) * i + t * t * largo * 0.35
        ancho = 1 + int(2 * np.sin(np.pi * t))
        for a in range(-ancho, ancho + 1):
            C.pix(px - np.sin(ang) * a * 0.6, py + np.cos(ang) * a * 0.6, c - 0.05 * abs(a))
        C.pix(px, py, c + 0.1)


# ---------------------------------------------------------------- arco
def arco(ruta):
    """Arco de Xantolo estilo Huejutla: armazón cubierto de palmilla, cempasúchil y mano de león."""
    rng = np.random.default_rng(30)
    W, H = 170, 190
    C = Capa(W, H)
    cx, base, r = W / 2, H - 1, 64
    cima = 66  # y donde empieza la curva
    # armazón (otate)
    for lado in (-1, 1):
        x = cx + lado * r
        C.linea(x - 2, base, x - 2, cima, 0.16, 5)
    for i in range(181):
        a = np.pi * i / 180
        C.disco(cx - np.cos(a) * r, cima - np.sin(a) * r, 2.5, 0.16)
    # palmilla que forra el armazón
    puntos = [(cx + lado * r, y) for lado in (-1, 1) for y in range(base - 4, cima, -3)]
    puntos += [(cx - np.cos(a) * r, cima - np.sin(a) * r) for a in np.linspace(0, np.pi, 70)]
    for (x, y) in puntos:
        for _ in range(3):
            ang = rng.uniform(0.4, 2.7)
            hoja_palma(C, x + rng.uniform(-4, 4), y, rng.uniform(10, 17), ang, rng.uniform(0.26, 0.36), rng)
    # banda de flores: cempasúchil alternado con mano de león
    k = 0
    for lado in (-1, 1):
        for y in range(base - 8, cima, -6):
            for dx in (-4, 4):
                x = cx + lado * r + dx + rng.uniform(-1, 1)
                yy = y + (3 if dx > 0 else 0)
                if k % 4 == 3:
                    mano_de_leon(C, x, yy, 4.5, 0.42, rng)
                else:
                    cempasuchil(C, x, yy, rng.uniform(4.0, 5.0), rng.uniform(0.62, 0.78), rng)
                k += 1
    for i, a in enumerate(np.linspace(0.02, np.pi - 0.02, 44)):
        for dr in (-4, 4):
            x, y = cx - np.cos(a) * (r + dr), cima - np.sin(a) * (r + dr)
            if (i + (dr > 0)) % 4 == 1:
                mano_de_leon(C, x, y, 4.5, 0.42, rng)
            else:
                cempasuchil(C, x, y, rng.uniform(4.0, 5.0), rng.uniform(0.64, 0.82), rng)
    # guirnaldas colgando dentro del arco
    for a in np.linspace(0.35, np.pi - 0.35, 7):
        x0, y0 = cx - np.cos(a) * (r - 6), cima - np.sin(a) * (r - 6)
        largo = rng.integers(14, 30)
        C.linea(x0, y0, x0, y0 + largo, 0.3)
        for j in range(4, largo, 6):
            cempasuchil(C, x0, y0 + j, 2.0, rng.uniform(0.62, 0.78), rng)
        cempasuchil(C, x0, y0 + largo + 1, 2.6, 0.82, rng)
    # corona en la cima: estrella de palma
    tx, ty = cx, cima - r - 6
    for a in np.linspace(0, 2 * np.pi, 9)[:-1]:
        C.linea(tx, ty, tx + np.cos(a) * 8, ty + np.sin(a) * 8, 0.3)
    cempasuchil(C, tx, ty, 4, 0.92, rng)
    C.imagen().save(ruta)
    return W * PX, H * PX


# ---------------------------------------------------------------- rocas
def roca(ruta, w, h, semilla, musgo=True):
    """Roca sólida con facetas (estilo pixel-art): cada cara tiene su propia luz; luna arriba-izquierda."""
    rng = np.random.default_rng(semilla)
    H = h + 4
    C = Capa(w, H)
    top = 3
    # silueta: domo irregular con base ancha
    perfil = []
    for x in range(w):
        t = (2 * x / (w - 1)) - 1
        domo = 1 - np.sqrt(max(0.0, 1 - t ** 4))
        perfil.append(top + int(domo * h * 0.55 + rng.integers(0, 2)))
    # facetas: puntos de Voronoi con una normal al azar cada uno
    n = max(4, (w * h) // 300)
    pts = np.column_stack([rng.uniform(0, w, n), rng.uniform(top, H, n)])
    normales = rng.uniform(-1, 1, (n, 2))
    yy, xx = np.mgrid[0:H, 0:w]
    d = np.hypot(xx[..., None] - pts[:, 0], yy[..., None] - pts[:, 1])
    orden = np.argsort(d, axis=2)
    celda = orden[..., 0]
    d1 = np.take_along_axis(d, orden[..., :1], 2)[..., 0]
    d2 = np.take_along_axis(d, orden[..., 1:2], 2)[..., 0]
    tex = ruido2d(H, w, 2, semilla)
    for x in range(w):
        for y in range(perfil[x], H):
            u = (y - top) / h
            nx_, ny_ = normales[celda[y, x]]
            luz = 0.25 + 0.06 * (-nx_ - ny_) - 0.12 * u - 0.05 * (x / w)
            if d2[y, x] - d1[y, x] < 1.0:
                luz -= 0.05          # arista entre caras
            C.pix(x, y, luz + (tex[y, x] - 0.5) * 0.05)
        y0 = perfil[x]
        C.pix(x, y0, 0.44 - 0.15 * (x / w) + rng.uniform(-0.03, 0.03))   # canto con luz de luna
    m = C.a > 0
    borde = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
    C.v[borde] = np.minimum(C.v[borde], 0.07)
    for x in range(w):  # el canto superior se queda claro
        C.v[perfil[x], x] = 0.44 - 0.14 * (x / w)
    if musgo:
        for x in range(2, w - 2):
            if rng.random() < 0.35:
                y0 = perfil[x]
                for j in range(1, rng.integers(2, 5)):
                    C.pix(x + (j > 2) * rng.choice([-1, 1]), y0 - j, 0.18 + 0.03 * j)
    for x in range(w):  # hierba en la base
        if rng.random() < 0.5:
            for j in range(rng.integers(1, 4)):
                C.pix(x, H - 1 - j, 0.12)
    C.imagen().save(ruta)
    return w * PX, H * PX


def tronco(ruta, w, h):
    """Tronco caído: cilindro con corteza a lo largo, nudos y corte con anillos."""
    rng = np.random.default_rng(5)
    H = h + 3
    C = Capa(w, H)
    vetas = ruido2d(H, w, 4, 6)
    for x in range(w - 7):
        for y in range(3, H):
            u = (y - 3) / (h - 1)
            cil = np.sin(np.pi * u)               # sombreado de cilindro
            v = 0.10 + 0.24 * cil * (1 - 0.6 * u)
            if abs(((y + vetas[y, x] * 6) % 4) - 2) < 0.6:
                v -= 0.06                         # surcos de la corteza a lo largo
            C.pix(x, y, v + rng.uniform(-0.015, 0.015))
        C.pix(x, 3, 0.42)
    for kx, ky in ((20, 9), (55, 13)):            # nudos
        C.disco(kx, ky, 2.5, 0.08)
        C.pix(kx - 1, ky - 1, 0.3)
    cx, cy, rr = w - 7, 3 + h / 2 - 0.5, h / 2
    for y in range(3, H):
        for x in range(w - 14, w):
            dd = np.hypot((x - cx) * 1.6, y - cy)
            if dd <= rr:
                C.pix(x, y, 0.44 - (int(dd * 1.2) % 3 == 0) * 0.14 - 0.1 * (dd / rr))
    for k in range(12):                           # rama seca
        C.pix(24 + k, 3 - k // 3, 0.2)
    C.imagen().save(ruta)
    return w * PX, H * PX


def piedra_rio(ruta, w, h, semilla):
    rng = np.random.default_rng(semilla)
    C = Capa(w, h)
    for y in range(h):
        for x in range(w):
            d = ((x - w / 2 + 0.5) / (w / 2)) ** 2 + ((y - h * 0.6) / (h * 0.6)) ** 2
            if d <= 1:
                C.pix(x, y, 0.42 - (y / h) * 0.26 - 0.08 * (x / w) + rng.uniform(-0.03, 0.03))
    for x in range(w):
        ys = np.where(C.a[:, x] > 0)[0]
        if len(ys):
            C.pix(x, ys[0], 0.7)                         # canto mojado
    for x in range(0, w, 2):                              # espuma en la base
        C.pix(x, h - 1, 0.62 if (x // 2) % 2 else 0.45, 0.8)
    C.imagen().save(ruta)
    return w * PX, h * PX


# ---------------------------------------------------------------- fondos
def cargar(ruta):
    return Image.open(ruta).convert("RGBA")


def fondo_1(original, ruta):
    """La vereda del cañaveral: el bosque original (espejo) + cerca de caña y nicho con veladora."""
    base = cargar(original).transpose(Image.FLIP_LEFT_RIGHT)
    base = Image.eval(base.convert("L"), lambda p: int(p * 0.9)).convert("RGBA")
    W, H = base.width // PX, base.height // PX
    C = Capa(W, H)
    rng = np.random.default_rng(12)
    suelo = SUELO
    # Cañaveral detrás de la cerca (lado izquierdo)
    for i, x in enumerate(range(6, 230, 4)):
        alto = int(rng.integers(70, 120))
        inc = rng.uniform(-0.1, 0.1)
        for j in range(alto):
            px = x + inc * j
            C.pix(px, suelo - 8 - j, 0.10 - (0.03 if j % 9 == 0 else 0))
            C.pix(px + 1, suelo - 8 - j, 0.13)
            if j % 9 == 0 and j > alto * 0.4:
                lado = rng.choice([-1, 1])
                largo = rng.integers(12, 26)
                for k in range(largo):
                    C.pix(px + lado * k, suelo - 8 - j - k * 0.5 + (k / largo) ** 2 * largo, 0.11)
    # Cerca de otate amarrada
    for x in range(0, 236, 14):
        C.linea(x, suelo + 4, x, suelo - 34, 0.2, 2)
    for y in (suelo - 26, suelo - 10):
        C.linea(0, y, 236, y + 1, 0.24, 1)
    # Nicho con cruz y veladora a la orilla de la vereda
    nx = gx(430)
    C.linea(nx - 10, suelo + 2, nx + 10, suelo + 2, 0.18, 1)
    for y in range(suelo - 14, suelo + 2):
        C.linea(nx - 9, y, nx + 9, y, 0.15)
    C.linea(nx, suelo - 40, nx, suelo - 14, 0.22, 2)
    C.linea(nx - 8, suelo - 32, nx + 8, suelo - 32, 0.22, 1)
    for k in range(3):
        cempasuchil(C, nx - 6 + k * 6, suelo - 16, 2.4, 0.7, rng)
    capa = C.imagen()
    # resplandor de la veladora
    luz = Capa(W, H)
    yy, xx = np.mgrid[0:H, 0:W]
    d = np.hypot(xx - (nx + 5), yy - (suelo - 8))
    luz.a = np.clip(1 - d / 40, 0, 1) ** 2 * 0.35
    luz.v[:] = 1.0
    C2 = Capa(W, H)
    C2.v[suelo - 12: suelo - 4, nx + 4: nx + 7] = 0.9
    C2.a[suelo - 12: suelo - 4, nx + 4: nx + 7] = 1
    out = Image.alpha_composite(base, luz.imagen(tramado=False))
    out = Image.alpha_composite(out, capa)
    out = Image.alpha_composite(out, C2.imagen(tramado=False))
    out.convert("L").save(ruta, optimize=True)


def fondo_3(original, ruta):
    """El claro de cempasúchil: acercamiento al valle (x2 exacto, sin borrosidad) + campo de flores y arroyo."""
    o = cargar(original)
    rec = o.crop((640, 96, 640 + 688, 96 + 384)).resize((1376, 768), Image.NEAREST)
    base = Image.eval(rec.convert("L"), lambda p: int(p * 0.95)).convert("RGBA")
    W, H = base.width // PX, base.height // PX
    rng = np.random.default_rng(33)
    C = Capa(W, H)
    suelo = SUELO
    horizonte = 262
    arroyo = (gx(567), gx(803))
    perfil = (ruido2d(1, W, 50, 3)[0] - 0.5) * 12
    tex = ruido2d(H, W, 3, 4)
    manchas = ruido2d(H, W, 18, 5)
    # Ladera oscura donde está sembrado el campo
    for x in range(W):
        for y in range(int(horizonte + perfil[x]), H):
            C.pix(x, y, 0.06 + (tex[y, x] - 0.5) * 0.04)
    # Surcos en perspectiva: pocas flores al fondo, grandes y claras al frente, en manchas
    y = horizonte + 3
    while y < H + 4:
        k = (y - horizonte) / (H - horizonte)
        paso = max(4, int(10 - k * 4))
        r = 1.0 + k * 3.6
        for x in range(int(rng.integers(0, paso)), W, paso):
            yy = y + rng.uniform(-1, 1) + perfil[min(x, W - 1)] * (1 - k)
            if manchas[min(int(yy), H - 1), x] < 0.38:
                continue
            if suelo - 3 < yy < suelo + 13:
                continue                     # vereda despejada
            if arroyo[0] - r - 3 < x < arroyo[1] + r + 3 and yy > suelo:
                continue                     # arroyo despejado
            for j in range(int(r * 1.6)):    # tallo
                C.pix(x, yy + r + j * 0.7, 0.10)
            if k > 0.3:                      # hojas dentadas
                for lado in (-1, 1):
                    for j in range(int(r)):
                        C.pix(x + lado * (1 + j), yy + r + 1 + j * 0.4, 0.13)
            if k > 0.25 and rng.random() < 0.35:   # matas de hojas oscuras entre las flores
                C.disco(x + rng.integers(-2, 3), yy + r * 0.8, r * 0.9, 0.09)
                continue
            cempasuchil(C, x, yy, r, 0.22 + k * 0.36 + rng.uniform(-0.07, 0.07), rng)
        y += 2 + int(k * 7)
    # Vereda
    for x in range(W):
        if arroyo[0] <= x <= arroyo[1]:
            continue
        for yy in range(suelo - 1, suelo + 12):
            C.pix(x, yy, 0.23 - abs(yy - (suelo + 4)) * 0.012 + (tex[yy, x] - 0.5) * 0.06)
    # Arroyo con orillas irregulares
    orilla = (ruido2d(H, 2, 5, 8) - 0.5) * 10
    for yy in range(suelo + 2, H):
        e = (yy - suelo) * 0.35
        a, b = int(arroyo[0] - e + orilla[yy, 0]), int(arroyo[1] + e + orilla[yy, 1])
        for x in range(a, b):
            C.pix(x, yy, 0.07 + 0.05 * (1 - (yy - suelo) / (H - suelo)) + (tex[yy, x] - 0.5) * 0.04)
        for d in range(3):
            C.pix(a - d, yy, 0.2 - d * 0.03)
            C.pix(b + d, yy, 0.2 - d * 0.03)
    for _ in range(80):
        x, yy = rng.integers(arroyo[0] + 3, arroyo[1] - 8), rng.integers(suelo + 4, H - 2)
        C.linea(x, yy, x + rng.integers(2, 7), yy, 0.38 + rng.random() * 0.22)
    out = Image.alpha_composite(base, C.imagen())
    out.convert("L").save(ruta, optimize=True)


if __name__ == "__main__":
    orig = os.path.join(FONDOS, "La_Sierra_de_los_Chaneques.png")
    fondo_1(orig, os.path.join(FONDOS, "sierra_1_canaveral.png"))
    fondo_3(orig, os.path.join(FONDOS, "sierra_3_cempasuchil.png"))
    tam = {
        "arco_xantolo": arco(os.path.join(SPR, "arco_xantolo.png")),
        "roca_baja": roca(os.path.join(SPR, "roca_baja.png"), 62, 23, 1),
        "roca_media": roca(os.path.join(SPR, "roca_media.png"), 56, 46, 2),
        "roca_alta": roca(os.path.join(SPR, "roca_alta.png"), 50, 69, 3),
        "tronco": tronco(os.path.join(SPR, "tronco.png"), 88, 22),
        "piedra_rio": piedra_rio(os.path.join(SPR, "piedra_rio.png"), 30, 13, 4),
    }
    for k, v in tam.items():
        print(k, v)
