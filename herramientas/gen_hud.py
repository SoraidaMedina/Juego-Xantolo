"""Íconos del HUD en pixel art (escala de grises), estilo de los sprites del juego.

Cada ícono es un mapa de caracteres; el contorno negro se agrega solo.
Se exportan a 1x (el HUD los agranda en múltiplos exactos para que se vean nítidos);
el marco se exporta a 2x porque se usa como 9-patch. Destino: assets/hud/.
Uso: python gen_hud.py ../assets/hud
"""
import os
import sys

from PIL import Image

ESCALA = 1        # íconos
ESCALA_MARCO = 2
# carácter -> (gris, alfa). 'k' es contorno; g/G/s/S son brillo y humo (sin contorno)
PALETA = {
    ".": None,
    "k": (14, 255),
    "d": (52, 255),
    "m": (96, 255),
    "l": (146, 255),
    "h": (198, 255),
    "w": (244, 255),
    "g": (255, 60),
    "G": (255, 140),
    "s": (170, 90),
    "S": (205, 150),
}
SIN_CONTORNO = set("gGsS.")

ICONOS = {}

# Veladora encendida con un corazón bordado = una vida. Su luz guía a las ánimas en el Xantolo.
ICONOS["vida"] = [
    "......g......",
    "...g..h......",
    ".....hwh.....",
    "....hwwwh..g.",
    "...hwwwwlh...",
    "...hwwwwlh...",
    "....hwwlh....",
    "......k......",
    "..mmmmmmmmm..",
    "..lwwwwwwwm..",
    "..lhwdwdwlm..",
    "..lhdddddlm..",
    "..lhdddddlm..",
    "..lhwdddwlm..",
    "..lhwwdwwlm..",
    "..lhwwwwwlm..",
    "..mlllllllm..",
    "...mmmmmmm...",
]
# Veladora apagada: vidrio oscuro y un hilo de humo
ICONOS["vida_apagada"] = [
    "......s......",
    ".....s.......",
    "......s......",
    ".......s.....",
    "......S......",
    ".....S.......",
    "......S......",
    "......k......",
    "..ddddddddd..",
    "..dmmmmmmmd..",
    "..dlmkmkmdd..",
    "..dlkkkkkdd..",
    "..dlkkkkkdd..",
    "..dlmkkkmdd..",
    "..dlmmkmmdd..",
    "..dlmmmmmdd..",
    "..ddddddddd..",
    "...ddddddd...",
]
# Llama de Chicomexochitl (barra de luz)
ICONOS["llama"] = [
    "...g.....g..",
    "......h.....",
    ".....hwh....",
    "....hwwwh...",
    "...hwwwwlh..",
    "..hwwwwwwlh.",
    "..hwwwwwwlh.",
    "..hwwwhwwlh.",
    "...hwhmhlh..",
    "....hlmlh...",
    ".....hhh....",
]
# --- Ofrenda ---
ICONOS["ofrenda_vela"] = [
    "..g......",
    "....h....",
    "...hwh..g",
    "..hwwwh..",
    "..hwwlh..",
    "...hwh...",
    "....k....",
    "..wwwwh..",
    "..whwlm..",
    "..wwwlmw.",
    "..whwlmw.",
    "..wwwlm..",
    "..whwlm..",
    "..wwwlm..",
    "..whwlm..",
    "..wwwlm..",
    ".dmmmmmd.",
    "..ddddd..",
]
ICONOS["ofrenda_flor"] = [
    ".....hwh.....",
    "...whlhlhw...",
    "..hwlwhwlwh..",
    ".hlhwlhlwhlh.",
    ".wlwhmlmhwlw.",
    "hlhwmdmdmwhlh",
    "wlwlmdkdmlwlw",
    "hlhwmdmdmwhlh",
    ".wlwhmlmhwlm.",
    ".hlhlhlhlhmm.",
    "..mlmlmlmmm..",
    "...mmmmmmm...",
    "......d......",
    "....md.......",
    "...mmd.......",
    "......d......",
]
ICONOS["ofrenda_petalos"] = [
    "...wh.........",
    "..whl.....hw..",
    "..hlm....whl..",
    "...m....hwlm..",
    ".........lm...",
    "......hw......",
    ".....whl......",
    ".hw..hlm..wh..",
    "whl...m..whlm.",
    "hlm.......lm..",
    ".m............",
]
ICONOS["ofrenda_juguete"] = [  # trompo
    "......k......",
    "......k......",
    "...hwwwwwl...",
    "..hwdddddlm..",
    ".hwwwwwwwwlm.",
    ".hddddddddmm.",
    "..hwwwwwwlm..",
    "...hwwwwlm...",
    "....hwwlm....",
    ".....hlm.....",
    "......m......",
    "......d......",
]
ICONOS["desconocido"] = [
    "...mmmmm...",
    "..mm...mm..",
    "..mm...mm..",
    ".......mm..",
    "......mm...",
    ".....mm....",
    ".....mm....",
    "...........",
    ".....mm....",
    ".....mm....",
]
# --- Recuerdos del abuelo (nivel de la cueva) ---
ICONOS["ofrenda_balero"] = [
    "..hwwwwlm...",
    "...hlllm....",
    "....hlm.....",
    "....hlmS....",
    "....hlm.S...",
    "....hlm..S..",
    "....hlm...S.",
    "....hlm..hwl",
    "....hlm..llm",
    "....hlm...m.",
    "....hlm.....",
    "....hlm.....",
    "....mmm.....",
]
ICONOS["ofrenda_foto"] = [  # retrato del abuelo con su moño de luto
    "kk........kk",
    "kmmmmmmmmmmk",
    "mhhhhhhhhhhm",
    "mhwwwwwwwwhm",
    "mhwwwddwwwhm",
    "mhwddddddwhm",
    "mhwwwddwwwhm",
    "mhwwddddwwhm",
    "mhwddddddwhm",
    "mhwddddddwhm",
    "mhhhhhhhhhhm",
    "mmmmmmmmmmmm",
]
# --- Talismanes ---
ICONOS["copal"] = [  # sahumerio de barro con humo de copal
    "....s...s....",
    ".....S.s.....",
    "....S...S....",
    ".....S.S.....",
    "......S......",
    "..hwwhwhwwl..",
    ".hmdmdmdmdml.",
    ".hlhwhwhwlmd.",
    "..hlhlhllmd..",
    "...hlllmmd...",
    "....hlmmd....",
    ".....lmd.....",
    "....hlmmd....",
    "...hlllmmd...",
    "...ddddddd...",
]
ICONOS["piedrita"] = [
    "...hhll...",
    "..hwhllm..",
    ".hwhlllmm.",
    ".hhllmlmd.",
    ".llmlmmmd.",
    "..lmmmmd..",
    "...dddd...",
]
ICONOS["papel_picado"] = [
    "dddddddddddddd",
    ".wwwwwwwwwwww.",
    ".w.ww.ww.ww.w.",
    ".ww..wwww..ww.",
    ".w.ww.ww.ww.w.",
    ".wwwwwwwwwwww.",
    ".www.wwww.www.",
    ".ww...ww...ww.",
    ".www.wwww.www.",
    ".wwwwwwwwwwww.",
    ".w.ww.ww.ww.w.",
    "..w..w..w..w..",
]
ICONOS["amuleto"] = [  # bordado con nahui ollin y borla
    "....d.d....",
    "..wwwwwwh..",
    ".whhwhwhhl.",
    ".whdhwhdhl.",
    ".wwhdwdhwl.",
    ".whwhdhwhl.",
    ".wwhdwdhwl.",
    ".whdhwhdhl.",
    ".whhwhwhhl.",
    "..lllllll..",
    ".....d.....",
    "....mdm....",
    "....mdm....",
    "...m.d.m...",
]
# --- Estados ---
ICONOS["escondida"] = [  # arbusto con ojos
    ".....mm.mm.....",
    "...mmlmmlmmm...",
    "..mlmmmmmlmlm..",
    ".mmlmdmmmmdmlm.",
    "mlmmwwmmmwwmmlm",
    "mmmmwkmmmwkmmmm",
    "mlmmmmmmmmmmmlm",
    ".mmlmmdmmmdmlm.",
    "..mmmlmmmlmmm..",
    "...ddddddddd...",
]
ICONOS["luz_oculta"] = [  # la mano cubre la llama
    "...........",
    ".....g.....",
    "....gGg....",
    "....GhG....",
    "....GmG....",
    "lh..ddd..hl",
    "hwh.....hwl",
    "hwwh...hwwl",
    ".hwwhhhwwl.",
    "..hwwwwwl..",
    "...lllll...",
]
ICONOS["ojo"] = [  # el Nahual vigila
    "......mmmmm......",
    "...mmlhhhhhlmm...",
    ".mlhww.ddd.wwhlm.",
    "mhww..dkkkd..wwhm",
    "mhww..dkwkd..wwhm",
    ".mlhww.ddd.wwhlm.",
    "...mmlhhhhhlmm...",
    "......mmmmm......",
]
ICONOS["mano"] = [  # lo que cargas en la mano
    "...h.h.h...",
    "..hwhwhwh..",
    "..hwhwhwh..",
    "h.hwhwhwh..",
    "whhwwwwwh..",
    "hwwwwwwwl..",
    ".hwwwwwwl..",
    "..hwwwwl...",
    "...lllll...",
]


def a_imagen(mapa):
    alto = len(mapa) + 2
    ancho = max(len(f) for f in mapa) + 2
    celdas = [["."] * ancho for _ in range(alto)]
    for y, fila in enumerate(mapa):
        for x, c in enumerate(fila):
            celdas[y + 1][x + 1] = c
    # Contorno automático alrededor de lo sólido
    contorno = [fila[:] for fila in celdas]
    for y in range(alto):
        for x in range(ancho):
            if celdas[y][x] not in ".gG":
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < ancho and 0 <= ny < alto and celdas[ny][nx] not in SIN_CONTORNO and celdas[ny][nx] != "k":
                    if celdas[y][x] == ".":
                        contorno[y][x] = "k"
                    break
    img = Image.new("LA", (ancho, alto), (0, 0))
    for y in range(alto):
        for x in range(ancho):
            v = PALETA[contorno[y][x]]
            if v:
                img.putpixel((x, y), v)
    img = img.convert("RGBA")
    return img.resize((ancho * ESCALA, alto * ESCALA), Image.NEAREST)


def marco():
    """Marco 9-patch con puntada de bordado y rombos (xinicuilli) en las esquinas."""
    n = 16
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    for y in range(n):
        for x in range(n):
            borde = min(x, y, n - 1 - x, n - 1 - y)
            if borde == 0:
                c = (10, 10, 10, 230)
            elif borde == 1:
                c = (120, 120, 120, 235)
            elif borde == 2:
                c = (8, 8, 8, 200)
            elif borde == 3 and (x + y) % 2 == 0:
                c = (170, 170, 170, 220)   # puntada
            else:
                c = (6, 6, 6, 165)
            img.putpixel((x, y), c)
    for cx, cy in ((2, 2), (n - 3, 2), (2, n - 3), (n - 3, n - 3)):
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            img.putpixel((cx + dx, cy + dy), (225, 225, 225, 255) if (dx, dy) == (0, 0) else (150, 150, 150, 255))
    return img.resize((n * ESCALA_MARCO, n * ESCALA_MARCO), Image.NEAREST)


def main():
    destino = sys.argv[1] if len(sys.argv) > 1 else "../assets/hud"
    os.makedirs(destino, exist_ok=True)
    for nombre, mapa in ICONOS.items():
        a_imagen(mapa).save(os.path.join(destino, nombre + ".png"))
    marco().save(os.path.join(destino, "marco.png"))
    print("ok", len(ICONOS) + 1, "íconos en", destino)


if __name__ == "__main__":
    main()
