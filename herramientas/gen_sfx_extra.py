"""Efectos nuevos: piedrita, campanas, murmullo del pueblo, vela que se enciende.
Uso: python gen_sfx_extra.py <carpeta assets/audio> <carpeta temporal>
"""
import os
import sys
import numpy as np
sys.argv = sys.argv[:3]
import gen_audio as A

rng = np.random.default_rng(77)


def piedrita():
    out = A.silencio(0.6)
    for t0, v in ((0.0, 1.0), (0.13, 0.5), (0.22, 0.25)):   # cae y rebota
        t = A.t_(0.05)
        clic = A.filtro(rng.standard_normal(len(t)), "band", [1500, 6000]) * np.exp(-t * 120)
        A.poner(out, t0, clic, v)
    return A.normalizar(A.reverb(out, 0.6, 0.2), 0.6)


def campana(f0, dur=4.0):
    t = A.t_(dur)
    s = np.zeros_like(t)
    for r, a, d in ((0.5, 0.5, 0.8), (1.0, 1.0, 1.2), (1.19, 0.6, 1.8), (1.5, 0.45, 2.0),
                    (2.0, 0.5, 2.5), (2.51, 0.3, 3.2), (2.66, 0.25, 3.5), (3.01, 0.2, 4.0)):
        s += a * np.sin(2 * np.pi * f0 * r * t) * np.exp(-t * d)
    return s


def campanas():
    out = A.silencio(9.0)
    notas = [A.f("D", 4), A.f("A", 3), A.f("F#", 4), A.f("D", 4)]
    for i in range(10):   # repique de pueblo
        A.poner(out, i * 0.55, campana(notas[i % 4], 3.5), 0.5 if i % 4 else 0.8)
    return A.normalizar(A.reverb(out, 2.5, 0.45), 0.6)


def murmullo(dur=20.0):
    """Voces lejanas de la gente del pueblo (bucle)."""
    out = A.silencio(dur)
    for _ in range(70):
        d = rng.uniform(0.6, 1.8)
        f0 = rng.uniform(110, 260)
        contorno = lambda t, f0=f0, d=d: f0 * (1 + 0.15 * np.sin(2 * np.pi * t / d * rng.uniform(1, 3)))
        v = A.voz(contorno, d, [(rng.uniform(500, 800), 150, 1.0), (rng.uniform(1100, 1800), 200, 0.6)], aliento=0.3)
        env = np.sin(np.pi * A.t_(d) / d) ** 1.5 * (0.6 + 0.4 * np.sin(2 * np.pi * 4 * A.t_(d)))
        A.poner(out, rng.uniform(0, dur - d), v * env, rng.uniform(0.2, 0.5))
    out = A.filtro(out, "low", 2500)
    return A.fundido_bucle(A.normalizar(A.reverb(out, 1.8, 0.5), 0.45), 0.5)


def vela():
    t = A.t_(0.9)
    soplo = A.filtro(rng.standard_normal(len(t)), "band", [400, 2500]) * np.exp(-t * 6) * np.minimum(1, t / 0.05)
    brillo = A.cuerda(A.f("A", 5), 0.9, 0.7, 4.0, 6) * 0.4
    return A.normalizar(A.reverb(soplo * 0.6 + brillo, 1.0, 0.3), 0.5)


if __name__ == "__main__":
    os.makedirs(os.path.join(A.TMP, "sfx"), exist_ok=True)
    for nombre, fn in [("piedrita", piedrita), ("campanas", campanas), ("murmullo", murmullo), ("vela", vela)]:
        A.guardar("sfx/" + nombre, fn(), 4)
        print(nombre)
