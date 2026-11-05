"""Genera fondos pixel-art en escala de grises para la Sierra (pantallas 1 y 3).
Se dibuja a 344x192 y se escala x4 con vecino más cercano, como el arte original (1376x768).
"""
import sys
import numpy as np
from PIL import Image

W, H = 344, 192
ESC = 4
SUELO = 164  # línea del camino (en px de baja resolución) ~ y=560 en el juego
rng = np.random.default_rng(7)

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def ruido1d(n, escala, semilla, octavas=4):
    r = np.random.default_rng(semilla)
    out = np.zeros(n)
    amp, tot = 1.0, 0.0
    for o in range(octavas):
        pts = r.random(int(n / escala * 2 ** o) + 3)
        xs = np.arange(n) / escala * 2 ** o
        i = xs.astype(int)
        f = xs - i
        f = f * f * (3 - 2 * f)
        out += amp * (pts[i] * (1 - f) + pts[i + 1] * f)
        tot += amp
        amp *= 0.5
    return out / tot


def ruido2d(h, w, escala, semilla):
    r = np.random.default_rng(semilla)
    gy, gx = int(h / escala) + 3, int(w / escala) + 3
    g = r.random((gy, gx))
    ys = np.arange(h)[:, None] / escala
    xs = np.arange(w)[None, :] / escala
    iy, ix = ys.astype(int), xs.astype(int)
    fy, fx = ys - iy, xs - ix
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a = g[iy, ix] * (1 - fx) + g[iy, ix + 1] * fx
    b = g[iy + 1, ix] * (1 - fx) + g[iy + 1, ix + 1] * fx
    return a * (1 - fy) + b * fy


class Lienzo:
    def __init__(self):
        self.v = np.zeros((H, W))

    def cielo(self, arriba, abajo, semilla=1):
        t = np.linspace(0, 1, H)[:, None]
        self.v[:] = arriba * (1 - t) + abajo * t
        nubes = ruido2d(H, W, 22, semilla) * 0.6 + ruido2d(H, W, 9, semilla + 1) * 0.4
        franja = np.clip(1 - np.abs(np.linspace(0, 1, H)[:, None] - 0.18) * 4, 0, 1)
        self.v += (nubes - 0.5) * 0.10 * franja

    def luna(self, cx, cy, r):
        yy, xx = np.mgrid[0:H, 0:W]
        d = np.hypot(xx - cx, yy - cy)
        halo = np.clip(1 - d / (r * 5), 0, 1) ** 2 * 0.12
        self.v += halo
        disco = d <= r
        manchas = ruido2d(H, W, 3, 99)
        self.v[disco] = 0.80 + (manchas[disco] - 0.5) * 0.12

    def cordillera(self, base, amp, escala, color, semilla, filo=1.0, desde=0, hasta=W):
        perfil = ruido1d(W, escala, semilla, 5)
        picos = np.abs(perfil - 0.5) * 2  # crestas afiladas (Sierra Madre Oriental)
        perfil = perfil * (1 - filo) + (1 - picos) * filo
        top = (base - perfil * amp).astype(int)
        tex = ruido2d(H, W, 4, semilla + 5)
        for x in range(desde, hasta):
            y0 = max(top[x], 0)
            col = self.v[y0:, x]
            sombra = np.linspace(0, 0.04, len(col))
            col[:] = color + (tex[y0:, x] - 0.5) * 0.04 - sombra
            if y0 < H:
                self.v[y0, x] = color + 0.06  # filo iluminado por la luna
        return top

    def niebla(self, centro, grosor, fuerza, valor=0.55, semilla=3):
        t = np.arange(H)[:, None]
        banda = np.exp(-((t - centro) / grosor) ** 2)
        mov = ruido2d(H, W, 26, semilla) * 0.7 + 0.3
        a = np.clip(banda * mov * fuerza, 0, 1)
        self.v = self.v * (1 - a) + valor * a

    def rect(self, x0, y0, x1, y1, c):
        x0, x1 = max(int(x0), 0), min(int(x1), W)
        y0, y1 = max(int(y0), 0), min(int(y1), H)
        if x1 > x0 and y1 > y0:
            self.v[y0:y1, x0:x1] = c

    def pix(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < H:
            self.v[y, x] = c

    def linea(self, x0, y0, x1, y1, c, grosor=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / max(n, 1)
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            for g in range(grosor):
                self.pix(x + g, y, c)

    def disco(self, cx, cy, r, c):
        for y in range(int(cy - r), int(cy + r) + 1):
            for x in range(int(cx - r), int(cx + r) + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.5:
                    self.pix(x, y, c)

    def resplandor(self, cx, cy, r, fuerza):
        yy, xx = np.mgrid[0:H, 0:W]
        d = np.hypot(xx - cx, yy - cy)
        self.v += np.clip(1 - d / r, 0, 1) ** 2 * fuerza

    def suelo(self, y, color, semilla=11):
        perfil = (ruido1d(W, 30, semilla, 3) - 0.5) * 3
        tex = ruido2d(H, W, 2.5, semilla + 1)
        for x in range(W):
            y0 = int(y + perfil[x])
            self.v[y0:, x] = color + (tex[y0:, x] - 0.5) * 0.05

    def vereda(self, y, color, semilla=12):
        # Camino de tierra apisonada, más claro al centro por la luna
        tex = ruido2d(H, W, 2, semilla)
        for yy in range(y, min(y + 14, H)):
            k = 1 - abs(yy - (y + 5)) / 9
            self.v[yy, :] = np.maximum(self.v[yy, :], color * k + (tex[yy, :] - 0.5) * 0.05)
        for _ in range(140):  # piedritas
            self.pix(rng.integers(0, W), rng.integers(y + 1, y + 12), color + 0.08)

    def pasto(self, y, alto, color, densidad=1.0, semilla=13):
        r = np.random.default_rng(semilla)
        for x in range(W):
            if r.random() < 0.85 * densidad:
                h = int(r.integers(2, alto + 1))
                inc = r.choice([-1, 0, 0, 1])
                for i in range(h):
                    self.pix(x + inc * (i // 3), y - i, color)

    def helecho(self, x, y, tam, color):
        for lado in (-1, 1):
            for i in range(tam):
                ang = 0.25 + i / tam * 1.0
                lx = x + lado * np.cos(ang) * i * 1.3
                ly = y - np.sin(ang) * i * 1.1 + (i / tam) ** 2 * tam * 0.5
                self.pix(lx, ly, color)
                if i % 2 == 0:
                    self.pix(lx, ly + 1, color)
                    self.pix(lx + lado, ly + 1, color)

    def cana(self, x, y_suelo, alto, color, semilla):
        """Tallo de caña de azúcar con nudos y hojas largas."""
        r = np.random.default_rng(semilla)
        inc = r.uniform(-0.12, 0.12)
        for i in range(alto):
            cx = x + inc * i
            nudo = (i % 7 == 0)
            self.pix(cx, y_suelo - i, color - (0.03 if nudo else 0))
            self.pix(cx + 1, y_suelo - i, color + 0.015)
            if nudo and i > alto * 0.35:
                lado = r.choice([-1, 1])
                largo = r.integers(8, 16)
                for k in range(largo):
                    self.pix(cx + lado * k, y_suelo - i - k * 0.6 + (k / largo) ** 2 * largo * 0.9, color)

    def platano(self, x, y_suelo, alto, color, semilla):
        r = np.random.default_rng(semilla)
        self.linea(x, y_suelo, x, y_suelo - alto, color, 2)
        for k in range(6):
            ang = r.uniform(-2.6, -0.5)
            largo = r.integers(14, 24)
            bx, by = x, y_suelo - alto
            for i in range(largo):
                t = i / largo
                px = bx + np.cos(ang) * i
                py = by + np.sin(ang) * i + t * t * largo * 0.8
                ancho = int(3 * np.sin(np.pi * t)) + 1
                for a in range(-ancho, ancho + 1):
                    if r.random() > 0.15 or abs(a) < ancho:  # hoja rasgada
                        self.pix(px - np.sin(ang) * a * 0.5, py + a * 0.5, color)

    def arbol(self, x, y_suelo, alto, copa, color, semilla):
        r = np.random.default_rng(semilla)
        self.linea(x, y_suelo, x, y_suelo - alto, color, 3)
        for _ in range(int(copa * 3)):
            ox, oy = r.normal(0, copa * 0.7), r.normal(0, copa * 0.35)
            self.disco(x + ox, y_suelo - alto + oy, r.uniform(copa * 0.25, copa * 0.5), color + r.uniform(-0.01, 0.02))

    def arco_cana(self, cx, y_suelo, ancho, alto, color, flor):
        """Arco de caña de azúcar adornado con cempasúchil: marca la entrada del Xantolo."""
        for lado in (-1, 1):
            px = cx + lado * ancho / 2
            self.linea(px, y_suelo, px, y_suelo - alto, color, 2)
        pts = []
        for i in range(int(ancho) + 1):
            t = i / ancho
            x = cx - ancho / 2 + i
            y = y_suelo - alto - np.sin(np.pi * t) * alto * 0.45
            pts.append((x, y))
            self.pix(x, y, color)
            self.pix(x, y + 1, color)
        for i, (x, y) in enumerate(pts):
            if i % 4 == 0:
                self.disco(x, y - 1, 2, flor)
                self.pix(x, y - 1, flor + 0.12)
        for lado in (-1, 1):  # flores colgando de los postes
            px = cx + lado * ancho / 2
            for k in range(0, int(alto), 6):
                self.disco(px + lado, y_suelo - alto + k, 1.5, flor - 0.05)

    def cruz_camino(self, x, y_suelo, color):
        """Pequeño nicho con cruz a la orilla de la vereda, con veladora encendida."""
        self.rect(x - 7, y_suelo - 6, x + 8, y_suelo, color + 0.03)
        self.rect(x - 1, y_suelo - 26, x + 1, y_suelo - 6, color)
        self.rect(x - 6, y_suelo - 21, x + 6, y_suelo - 19, color)
        self.resplandor(x + 4, y_suelo - 9, 18, 0.18)
        self.rect(x + 3, y_suelo - 10, x + 5, y_suelo - 6, 0.85)
        self.pix(x + 4, y_suelo - 11, 0.95)

    def cempasuchil(self, x, y, r, c):
        self.disco(x, y, r, c)
        for a in np.linspace(0, 2 * np.pi, 7)[:-1]:
            self.pix(x + np.cos(a) * r, y + np.sin(a) * r, c - 0.06)
        self.pix(x, y, c + 0.1)

    def arroyo(self, x0, x1, y0, y1, semilla=21):
        tex = ruido2d(H, W, 3, semilla)
        orilla = ruido1d(H, 6, semilla, 2) * 6
        for y in range(y0, H):
            a = int(x0 - orilla[y] - (y - y0) * 0.3)
            b = int(x1 + orilla[H - 1 - y] + (y - y0) * 0.3)
            t = (y - y0) / max(H - y0, 1)
            self.v[y, a:b] = 0.09 + 0.06 * (1 - t) + (tex[y, a:b] - 0.5) * 0.04
            self.pix(a, y, 0.22)
            self.pix(b, y, 0.22)
        r = np.random.default_rng(semilla)
        for _ in range(70):  # reflejos de luna, rotos por la corriente
            x, y = r.integers(x0 + 2, x1 - 6), r.integers(y0 + 2, H - 2)
            self.linea(x, y, x + r.integers(2, 5), y, 0.40 + r.random() * 0.2)

    def vineta(self, fuerza=0.35):
        yy, xx = np.mgrid[0:H, 0:W]
        d = np.hypot((xx - W / 2) / (W / 2), (yy - H / 2) / (H / 2))
        self.v *= 1 - np.clip(d - 0.55, 0, 1) * fuerza

    def guardar(self, ruta):
        v = np.clip(self.v, 0, 1)
        # Tramado ordenado: da el grano pixel-art en lugar de degradados lisos
        umbral = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
        niveles = 24
        q = np.floor(v * niveles + umbral) / niveles
        img = (np.clip(q, 0, 1) * 255).astype(np.uint8)
        im = Image.fromarray(img, "L").resize((W * ESC, H * ESC), Image.NEAREST).convert("RGBA")
        im.save(ruta)


def pantalla1(ruta):
    """La vereda del cañaveral: entrada a la sierra con el arco de caña del Xantolo."""
    L = Lienzo()
    L.cielo(0.10, 0.24, semilla=4)
    L.luna(60, 30, 9)
    L.cordillera(110, 55, 60, 0.21, 31, filo=0.8)
    L.niebla(105, 14, 0.7, 0.30)
    L.cordillera(128, 40, 45, 0.15, 32, filo=0.6)
    L.niebla(126, 10, 0.6, 0.26)
    # Platanar y árboles al fondo
    for i, x in enumerate(range(-10, W + 20, 26)):
        L.arbol(x + rng.integers(-6, 6), 150, rng.integers(26, 40), rng.integers(10, 15), 0.09, 50 + i)
    for i, x in enumerate([30, 95, 250, 300]):
        L.platano(x, 156, rng.integers(28, 36), 0.075, 70 + i)
    L.niebla(150, 9, 0.45, 0.22)
    # Cañaveral a la derecha
    for i, x in enumerate(range(200, W, 4)):
        L.cana(x + rng.integers(-1, 2), 162, int(rng.integers(40, 62)), 0.065, 100 + i)
    L.suelo(SUELO - 4, 0.07)
    L.vereda(SUELO - 2, 0.20)
    L.arco_cana(150, SUELO - 1, 46, 52, 0.06, 0.62)
    L.cruz_camino(60, SUELO - 1, 0.07)
    for x in range(0, W, 9):
        L.helecho(x + rng.integers(-3, 3), H - 2, int(rng.integers(8, 14)), 0.035)
    L.pasto(H - 1, 9, 0.04, 0.9)
    L.vineta(0.4)
    L.guardar(ruta)


def pantalla3(ruta):
    """El campo de cempasúchil y el arroyo: flores sembradas en junio que florecen para las ánimas."""
    L = Lienzo()
    L.cielo(0.09, 0.22, semilla=8)
    L.luna(290, 26, 10)
    L.cordillera(100, 60, 70, 0.20, 41, filo=0.9)
    L.niebla(98, 13, 0.75, 0.30)
    L.cordillera(122, 35, 40, 0.15, 42, filo=0.5)
    # Ladera de flores en la media distancia
    top = L.cordillera(140, 14, 80, 0.12, 43, filo=0.0)
    for _ in range(900):
        x = rng.integers(0, W)
        y = rng.integers(top[x] + 1, 150)
        L.cempasuchil(x, y, 0.7 + (y - 120) / 40, 0.30 + (y - 120) / 160)
    L.niebla(132, 8, 0.5, 0.26)
    for i, x in enumerate([18, 70, 318]):
        L.arbol(x, 152, rng.integers(36, 48), rng.integers(12, 16), 0.075, 80 + i)
    L.suelo(SUELO - 4, 0.07)
    L.vereda(SUELO - 2, 0.19)
    # Arroyo que corta la vereda (se cruza saltando de piedra en piedra)
    L.arroyo(168, 238, SUELO - 4, H)
    # Primer plano: flores grandes y helechos
    for x in range(0, W, 7):
        if 150 < x < 255:
            continue
        L.cempasuchil(x + rng.integers(-2, 3), H - rng.integers(4, 14), rng.uniform(1.5, 2.5), 0.38)
    for x in range(0, W, 14):
        if 150 < x < 255:
            continue
        L.helecho(x, H - 1, int(rng.integers(8, 13)), 0.04)
    L.vineta(0.4)
    L.guardar(ruta)


if __name__ == "__main__":
    salida = sys.argv[1]
    pantalla1(salida + "/sierra_1_canaveral.png")
    pantalla3(salida + "/sierra_3_cempasuchil.png")


def base_original(ruta, voltear=False, recorte=None):
    im = Image.open(ruta).convert("L")
    if recorte:
        im = im.crop(recorte)
    im = im.resize((W, H), Image.BOX)
    a = np.asarray(im).astype(float) / 255.0
    return a[:, ::-1].copy() if voltear else a


def pantalla1_v2(orig, ruta):
    L = Lienzo()
    L.v = base_original(orig, voltear=True) * 0.92
    # Cañaveral entre el camino y el bosque (lado izquierdo, tras la vereda)
    for i, x in enumerate(range(4, 120, 3)):
        L.cana(x + rng.integers(-1, 2), 160, int(rng.integers(34, 56)), 0.06, 300 + i)
    L.niebla(150, 8, 0.35, 0.20, semilla=5)
    L.arco_cana(176, SUELO - 3, 44, 50, 0.05, 0.66)
    L.cruz_camino(268, SUELO - 3, 0.06)
    L.guardar(ruta)


def pantalla3_v2(orig, ruta):
    L = Lienzo()
    # Otro encuadre del mismo valle: más cerca de las montañas y la luna
    L.v = base_original(orig, recorte=(470, 30, 1376, 536)) * 0.95
    # Ladera de cempasúchil delante del bosque
    corte = 132
    perfil = (ruido1d(W, 50, 61, 3) - 0.5) * 10
    tex = ruido2d(H, W, 3, 62)
    for x in range(W):
        y0 = int(corte + perfil[x])
        for y in range(y0, H):
            L.v[y, x] = 0.08 + (tex[y, x] - 0.5) * 0.04
    # Surcos de flores: manchas agrupadas, más grandes y claras hacia el frente
    manchas = ruido2d(H, W, 14, 63)
    for fila, y in enumerate(range(corte + 3, SUELO - 4, 3)):
        k = (y - corte) / (SUELO - corte)
        for x in range(fila % 2, W, 3 + int((1 - k) * 2)):
            yy = y + rng.integers(-1, 2) + perfil[x] * (1 - k)
            if manchas[int(min(yy, H - 1)), x] > 0.45 and rng.random() < 0.8:
                L.cempasuchil(x, yy, 0.5 + k * 1.1, 0.17 + k * 0.17 + rng.uniform(-0.02, 0.02))
    L.niebla(corte + 4, 6, 0.45, 0.24, semilla=9)
    L.vereda(SUELO - 2, 0.19)
    L.arroyo(168, 238, SUELO - 4, H)
    for x in range(0, W, 6):
        if 150 < x < 256:
            continue
        L.cempasuchil(x + rng.integers(-2, 3), H - rng.integers(4, 15), rng.uniform(1.5, 2.6), 0.40)
    for x in range(0, W, 13):
        if 150 < x < 256:
            continue
        L.helecho(x, H - 1, int(rng.integers(8, 13)), 0.04)
    L.vineta(0.25)
    L.guardar(ruta)
