"""Imágenes para los sustos (jumpscares): la cabeza de cada enemigo en primer plano,
oscurecida, con los ojos vacíos y un punto de luz, grano, viñeta e interferencia.
Sin sangre ni gore: es terror de folclor para 13+.
Uso: python gen_sustos.py <raíz del proyecto>
"""
import os
import sys
import numpy as np
from PIL import Image, ImageFilter

RAIZ = sys.argv[1] if len(sys.argv) > 1 else ".."
OUT = os.path.join(RAIZ, "assets", "sustos")
os.makedirs(OUT, exist_ok=True)
W, H = 1152, 648

# archivo, recorte 16:9 de la cabeza, ojos (x, y, radio) en coordenadas de la imagen original
FUENTES = {
    "chaneque": ("assets/chaneques/chaneque_idle.png", (260, 214, 780, 506), [(522, 402, 26), (620, 393, 22)]),
    "llorona": ("assets/llorona/llorona_cry.png", (480, 202, 1040, 517), []),
    "nahual": ("assets/nahual/nahual_detect.png", (430, 175, 950, 467), [(660, 328, 30)]),
}


def procesar(ruta, recorte, ojos, semilla):
    rng = np.random.default_rng(semilla)
    im = Image.open(os.path.join(RAIZ, ruta)).convert("RGBA")
    fondo = Image.new("RGBA", im.size, (0, 0, 0, 255))
    im = Image.alpha_composite(fondo, im).convert("L")
    a = np.asarray(im).astype(float) / 255.0
    # Ojos vacíos: cuenca negra con un punto de luz al centro
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    for (ox, oy, r) in ojos:
        d = np.hypot(xx - ox, yy - oy)
        a[d < r * 1.25] = 0.0
        a += np.exp(-(d / (r * 0.35)) ** 2) * 1.2
    a = np.clip(a, 0, 1)
    x0, y0, x1, y1 = recorte
    a = a[y0:y1, x0:x1]
    im = Image.fromarray((a * 255).astype(np.uint8), "L").resize((W, H), Image.NEAREST)
    a = np.asarray(im).astype(float) / 255.0
    a = np.clip((a - 0.08) * 1.5, 0, 1) ** 1.7       # sombras profundas, luces duras
    Y, X = np.mgrid[0:H, 0:W]
    d = np.hypot((X - W / 2) / (W / 2), (Y - H / 2) / (H / 2))
    a *= np.clip(1.3 - d * 1.0, 0, 1)                 # viñeta
    a += rng.normal(0, 0.05, a.shape)                 # grano
    for _ in range(7):                                # interferencia
        y = rng.integers(0, H - 20)
        h = rng.integers(3, 14)
        a[y:y + h] = np.roll(a[y:y + h], rng.integers(-50, 50), axis=1)
    a[::3] *= 0.85                                    # líneas de barrido
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L")


if __name__ == "__main__":
    for i, (nombre, (ruta, rec, ojos)) in enumerate(FUENTES.items()):
        procesar(ruta, rec, ojos, i).save(os.path.join(OUT, f"susto_{nombre}.png"), optimize=True)
    print("ok", sorted(os.listdir(OUT)))
