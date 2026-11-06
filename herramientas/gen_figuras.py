"""Figuras del pueblo para el final (y la piedrita): siluetas pixel-art en escala de grises.

- Ánimas: figuras blancas translúcidas que se desvanecen hacia los pies (flotan).
- Familia: siluetas oscuras con luz de borde (estilo Limbo/Inside).
- Cuadrilla de disfrazados (Xantolo de Huejutla): máscara de madera, sombrero con listones;
  2 cuadros de baile en una tira horizontal (hframes = 2).
Uso: python gen_figuras.py <raíz del proyecto>
"""
import os
import sys
import numpy as np
from PIL import Image, ImageFilter

PX = 2
RAIZ = sys.argv[1] if len(sys.argv) > 1 else ".."
OUT = os.path.join(RAIZ, "assets", "pueblo")
os.makedirs(OUT, exist_ok=True)
W, H = 40, 80   # cuadrícula de cada figura (80 x 160 px reales)


class Mascara:
    def __init__(self):
        self.m = np.zeros((H, W), bool)        # silueta
        self.cara = np.zeros((H, W), bool)     # zona de máscara/rostro (más clara)
        self.det = np.zeros((H, W), bool)      # detalles oscuros sobre la máscara
        self.luz = np.zeros((H, W), bool)      # detalles claros (listones, flores)

    def _set(self, capa, x, y):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < H:
            capa[y, x] = True

    def elipse(self, cx, cy, rx, ry, capa=None):
        capa = self.m if capa is None else capa
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x - cx) / max(rx, 0.1)) ** 2 + ((y - cy) / max(ry, 0.1)) ** 2 <= 1.0:
                    self._set(capa, x, y)

    def trapecio(self, y0, y1, cx0, w0, cx1, w1, capa=None):
        capa = self.m if capa is None else capa
        for y in range(int(y0), int(y1) + 1):
            t = (y - y0) / max(y1 - y0, 1)
            cx = cx0 + (cx1 - cx0) * t
            w = w0 + (w1 - w0) * t
            for x in range(int(cx - w / 2), int(cx + w / 2) + 1):
                self._set(capa, x, y)

    def linea(self, x0, y0, x1, y1, grosor=2, capa=None):
        capa = self.m if capa is None else capa
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / n
            for g in range(grosor):
                for h in range(grosor):
                    self._set(capa, x0 + (x1 - x0) * t + g - grosor // 2, y0 + (y1 - y0) * t + h - grosor // 2)


def persona(alto=66, sombrero=False, rebozo=False, falda=False, baston=False, encorvado=0.0,
            trenzas=False, nino=False, mascara=None, listones=False, cuadro=0, brazos="abajo",
            instrumento=None, canasta=False, morral=False, correr=False, sahumerio=False):
    """Construye la silueta. alto en celdas (66 ≈ 132 px). cuadro 0/1 = paso de baile."""
    M = Mascara()
    piso = H - 1
    cx = W / 2
    cabeza_r = 5.2 if not nino else 4.6
    top = piso - alto
    hy = top + cabeza_r + (4 if sombrero else 1)
    hx = cx + encorvado * 3
    cadera = top + alto * 0.55
    hombro = hy + cabeza_r + 2.5
    # Piernas (en baile una rodilla sube, alternando)
    for lado in (-1, 1):
        x0 = cx + lado * 2.4
        sube = (cuadro == 0 and lado == -1) or (cuadro == 1 and lado == 1)
        if (mascara or correr) and sube:
            rod_y = cadera + (piso - cadera) * 0.45
            M.linea(x0, cadera, x0 + lado * 1 + 3, rod_y, 5)
            M.linea(x0 + lado * 1 + 3, rod_y, x0 + lado * 1 + 1, piso - 6, 4)
            M.elipse(x0 + lado + 2.5, piso - 6, 2.4, 1.2)       # huarache en el aire
        else:
            M.trapecio(cadera, piso - 1, x0, 5.5, x0 + lado * 0.8, 4)
            M.elipse(x0 + lado * 0.8 + 1, piso - 0.5, 2.4, 1.0)  # huarache
    # Torso y cabeza
    M.trapecio(hombro, cadera + 1, hx, 16 if not nino else 12, cx, 12 if not nino else 10)
    M.trapecio(hy + cabeza_r - 1, hombro + 1, hx, 3.5, hx, 4)   # cuello
    M.elipse(hx, hy, cabeza_r * 0.9, cabeza_r)
    if falda:
        M.trapecio(cadera - 3, piso - (1 if not mascara else 8), cx, 10, cx, 17)
    if rebozo:
        M.trapecio(hy - cabeza_r - 0.5, hombro + 6, hx, 10, hx, 16)
        M.linea(hx + 7, hombro + 4, hx + 5, cadera + 6, 3)       # punta del rebozo
    if trenzas:
        M.linea(hx - 3.5, hy + 2, hx - 4.5, hombro + 9, 2)
        M.linea(hx + 3.5, hy + 2, hx + 4.5, hombro + 9, 2)
    if sombrero:
        M.elipse(hx, hy - cabeza_r + 1.5, 12.5, 1.8)               # ala
        M.trapecio(hy - cabeza_r - 4, hy - cabeza_r + 1, hx, 7, hx, 9)  # copa
    # Brazos
    for lado in (-1, 1):
        x0 = hx + lado * 7.5
        if brazos == "baile":
            arriba = (cuadro == 0) == (lado == 1)
            if arriba:   # brazo arriba con pañuelo
                M.linea(x0, hombro + 1, x0 + lado * 5, hombro - 7, 4)
                M.linea(x0 + lado * 5, hombro - 7, x0 + lado * 6, hombro - 14, 4)
                M.elipse(x0 + lado * 7, hombro - 16, 2.2, 2.2, M.luz)
            else:
                M.linea(x0, hombro + 1, x0 + lado * 6, hombro + 8, 4)
                M.linea(x0 + lado * 6, hombro + 8, x0 + lado * 3, cadera, 4)
        else:
            M.linea(x0, hombro + 1, x0 + lado * 2, cadera + 2, 4)
    if baston:
        M.linea(hx + 8, hombro + 9, hx + 11, piso, 2)
        M.linea(hx + 6, hombro + 9, hx + 8, hombro + 9, 2)
    # Máscara de madera de la cuadrilla
    if mascara:
        M.elipse(hx, hy + 0.5, cabeza_r * 1.05, cabeza_r * 1.15, M.cara)
        M._set(M.det, hx - 1.8, hy - 0.8)
        M._set(M.det, hx + 1.8, hy - 0.8)
        M.linea(hx - 1.5, hy + 2.6, hx + 1.5, hy + 2.6, 1, M.det)
        if mascara == "huehue":   # viejo: nariz larga y barba
            M.linea(hx, hy, hx + 3.5, hy + 1.5, 2, M.cara)
            M.trapecio(hy + 3, hy + 9, hx, 6, hx, 2, M.cara)
            M.trapecio(hy + 3, hy + 9, hx, 6, hx, 2)
        elif mascara == "diablo":  # cuernos
            M.linea(hx - 3, hy - 3, hx - 6, hy - 9, 2)
            M.linea(hx + 3, hy - 3, hx + 6, hy - 9, 2)
            M.linea(hx - 2.2, hy - 1.6, hx - 0.8, hy - 0.8, 1, M.det)
            M.linea(hx + 2.2, hy - 1.6, hx + 0.8, hy - 0.8, 1, M.det)
        elif mascara == "muerte":  # calavera
            M._set(M.det, hx - 0.5, hy + 1)
            M._set(M.det, hx + 0.5, hy + 1)
    # Trío huasteco: violín, jarana o quinta huapanguera (2 cuadros: arco / rasgueo)
    if instrumento == "violin":
        M.elipse(hx - 6, hombro + 2, 4.5, 2.8, M.cara)                          # cuerpo del violín en el hombro
        M.linea(hx - 2, hombro + 1, hx - 14, hombro + 6, 2, M.cara)                  # mástil
        ang = 0.35 if cuadro == 0 else -0.25                             # el arco va y viene
        bx, by = hx + 3, hombro + 3
        M.linea(bx, by, bx + 14 * np.cos(ang), by - 14 * np.sin(ang) - 2, 1, M.luz)
        M.linea(hx + 7, hombro + 1, bx, by, 3)                           # brazo del arco
    elif instrumento in ("jarana", "huapanguera"):
        r = 4.5 if instrumento == "jarana" else 6.5
        cy = cadera - 3
        M.elipse(hx + 1, cy, r + 1.5, r, M.cara)                                       # caja
        M.elipse(hx, cy, 1.2, 1.2, M.det)                                # boca
        M.linea(hx - 3, cy - 1, hx - 15, cy - 10 - (r - 4.5), 2, M.cara)          # mástil
        ry = cy - 4 if cuadro == 0 else cy + 3                           # mano que rasguea
        M.linea(hx + 7, hombro + 1, hx + 4, ry, 3)
    if sahumerio:  # sahumerio de barro colgando de la mano; se mece (cuadro 0/1)
        mx, my = hx + 9, hombro + 10                                     # mano
        M.linea(hx + 6, hombro + 1, mx, my, 3)                           # brazo al frente
        vaiven = 4 if cuadro == 0 else -2
        bx, by = mx + vaiven, my + 9
        M.linea(mx, my, bx, by - 2, 1, M.det)                            # cadenita
        M.trapecio(by - 2, by + 2, bx, 6, bx, 4, M.cara)                 # cazoleta de barro
        M.linea(bx, by + 2, bx, by + 4, 2, M.cara)
        M.elipse(bx, by - 3, 1.5, 1.0, M.luz)                            # brasa del copal
        print("sahumerio cuadro", cuadro, "brasa en px", (bx * PX - W * PX / 2, (by - 3) * PX - H * PX / 2))
    if canasta:  # canasta de flores en la cabeza
        M.trapecio(hy - cabeza_r - 5, hy - cabeza_r - 1, hx, 13, hx, 9)
        for k in range(5):
            M.elipse(hx - 5 + k * 2.5, hy - cabeza_r - 6.5, 1.8, 1.6, M.luz)
    if morral:  # morral cruzado
        M.linea(hx - 6, hombro, hx + 5, cadera - 2, 1, M.det)
        M.trapecio(cadera - 4, cadera + 3, hx + 6, 6, hx + 6, 7)
    if listones:
        for k, dx in enumerate((-12, -10, 10, 12)):
            vaiven = (1 if (cuadro + k) % 2 else -1) * 1.5
            ytop = hy - cabeza_r + 2
            M.linea(hx + dx, ytop, hx + dx + vaiven, ytop + 12 + k % 2 * 4, 1, M.luz)
    return M


def a_imagen(M, estilo, semilla=0):
    rng = np.random.default_rng(semilla)
    v = np.zeros((H, W))
    a = np.zeros((H, W))
    m = M.m | M.cara
    if estilo == "anima":
        y = np.arange(H)[:, None] / H
        v[m] = 0.95
        a[m] = 1.0
        a *= np.clip(1.25 - y * 1.1, 0.0, 1.0)            # se desvanece hacia los pies
        v[M.det] = 0.6
    else:
        tex = rng.uniform(-0.015, 0.015, (H, W))
        v[m] = 0.10 + tex[m]
        a[m] = 1.0
        borde = m & ~np.roll(m, 1, axis=1)                  # luz de borde (luna/amanecer a la izquierda)
        borde |= m & ~np.roll(m, 1, axis=0)
        v[borde] = 0.30
        v[M.cara] = 0.44 + tex[M.cara] * 2                 # máscara de madera
        v[M.cara & ~np.roll(M.cara, -1, axis=1)] = 0.40     # sombra de la máscara
        v[M.det] = 0.12
        v[M.luz] = 0.78
        a[M.luz] = 1.0
    g = (np.clip(v, 0, 1) * 255).astype(np.uint8)
    al = (np.clip(a, 0, 1) * 255).astype(np.uint8)
    im = Image.fromarray(np.dstack([g, g, g, al]), "RGBA").resize((W * PX, H * PX), Image.NEAREST)
    if estilo == "anima":  # halo suave alrededor
        halo = im.split()[3].filter(ImageFilter.GaussianBlur(7)).point(lambda p: int(p * 0.55))
        fondo = Image.new("RGBA", im.size, (255, 255, 255, 0))
        fondo.putalpha(halo)
        im = Image.alpha_composite(fondo, im)
    return im


def guardar(nombre, cuadros):
    if len(cuadros) == 1:
        cuadros[0].save(os.path.join(OUT, nombre + ".png"))
    else:
        tira = Image.new("RGBA", (cuadros[0].width * len(cuadros), cuadros[0].height))
        for i, c in enumerate(cuadros):
            tira.paste(c, (i * c.width, 0))
        tira.save(os.path.join(OUT, nombre + ".png"))


if __name__ == "__main__":
    # Ánimas que regresan
    guardar("anima_abuelo", [a_imagen(persona(64, sombrero=True, baston=True, encorvado=0.6), "anima")])
    guardar("anima_mujer", [a_imagen(persona(62, rebozo=True, falda=True, trenzas=True), "anima")])
    guardar("anima_hombre", [a_imagen(persona(66, sombrero=True), "anima")])
    # Familia
    guardar("familia_mama", [a_imagen(persona(62, rebozo=True, falda=True, trenzas=True), "silueta", 1)])
    guardar("familia_papa", [a_imagen(persona(68, sombrero=True), "silueta", 2)])
    guardar("familia_nino", [a_imagen(persona(42, nino=True), "silueta", 3)])
    guardar("familia_tia", [a_imagen(persona(60, falda=True, trenzas=True), "silueta", 4)])
    # Cuadrilla de disfrazados (2 cuadros de baile)
    for nombre, kw in [("disfrazado_huehue", dict(sombrero=True, mascara="huehue", listones=True)),
                       ("disfrazado_diablo", dict(mascara="diablo")),
                       ("disfrazado_mujer", dict(falda=True, rebozo=True, mascara="huehue")),
                       ("disfrazado_muerte", dict(sombrero=True, mascara="muerte", listones=True))]:
        guardar(nombre, [a_imagen(persona(66, brazos="baile", cuadro=c, **kw), "silueta", 7) for c in (0, 1)])
    # Gente del pueblo (amanecer del Xantolo)
    guardar("musico_violin", [a_imagen(persona(66, sombrero=True, instrumento="violin", cuadro=c), "silueta", 11) for c in (0, 1)])
    guardar("musico_jarana", [a_imagen(persona(65, sombrero=True, instrumento="jarana", cuadro=c), "silueta", 12) for c in (0, 1)])
    guardar("musico_huapanguera", [a_imagen(persona(67, sombrero=True, instrumento="huapanguera", cuadro=c), "silueta", 13) for c in (0, 1)])
    guardar("senora_canasta", [a_imagen(persona(60, rebozo=True, falda=True, canasta=True), "silueta", 14)])
    guardar("senor_morral", [a_imagen(persona(67, sombrero=True, morral=True), "silueta", 15)])
    guardar("abuelita", [a_imagen(persona(56, rebozo=True, falda=True, encorvado=0.8, baston=True), "silueta", 16)])
    guardar("nina", [a_imagen(persona(40, nino=True, falda=True, trenzas=True), "silueta", 17)])
    guardar("nino_corriendo", [a_imagen(persona(40, nino=True, correr=True, cuadro=c, brazos="baile"), "silueta", 18) for c in (0, 1)])
    guardar("joven", [a_imagen(persona(64), "silueta", 19)])
    guardar("sahumadora", [a_imagen(persona(60, rebozo=True, falda=True, sahumerio=True, cuadro=c), "silueta", 20) for c in (0, 1)])
    # Cancha: aro de básquet y pelota
    aro = Mascara()
    for y in range(H):
        for x in range(W):
            pass
    a_w, a_h = 30, 80
    v = np.zeros((a_h, a_w)); al = np.zeros((a_h, a_w))
    v[14:, 3:6] = 0.18; al[14:, 3:6] = 1                     # poste
    v[2:16, 4:26] = 0.62; al[2:16, 4:26] = 1                 # tablero
    v[2, 4:26] = v[15, 4:26] = 0.3; v[2:16, 4] = v[2:16, 25] = 0.3
    v[8:14, 12:18] = 0.4                                      # cuadro del tablero
    v[16, 14:28] = 0.25; al[16, 14:28] = 1                   # aro
    for k in range(6):                                        # red
        for x in (15 + k % 2, 19, 23 + k % 2, 27 - k // 2):
            if x < a_w:
                v[17 + k, x] = 0.7; al[17 + k, x] = 0.8
    g = (v * 255).astype(np.uint8); A_ = (al * 255).astype(np.uint8)
    Image.fromarray(np.dstack([g, g, g, A_]), "RGBA").resize((a_w * PX, a_h * PX), Image.NEAREST).save(os.path.join(OUT, "aro_basquet.png"))
    pel = Image.new("RGBA", (6, 6))
    pp = pel.load()
    for y in range(6):
        for x in range(6):
            if (x - 2.5) ** 2 + (y - 2.5) ** 2 <= 7:
                gv = 90 if (x == 2 or y == 3) else 150
                pp[x, y] = (gv, gv, gv, 255)
    pel.resize((12, 12), Image.NEAREST).save(os.path.join(OUT, "pelota.png"))
    # Piedrita para distraer chaneques
    p = Image.new("RGBA", (6, 5))
    px = p.load()
    for y in range(5):
        for x in range(6):
            if ((x - 2.5) / 3) ** 2 + ((y - 2.2) / 2.5) ** 2 <= 1:
                g = int(255 * (0.55 - 0.08 * y - 0.03 * x))
                px[x, y] = (g, g, g, 255)
    p.resize((12, 10), Image.NEAREST).save(os.path.join(OUT, "piedrita.png"))
    print("ok", sorted(os.listdir(OUT)))
