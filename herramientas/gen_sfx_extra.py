"""Efectos nuevos: piedrita, campanas, murmullo del pueblo, vela que se enciende, viento de la cueva.
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


def susto():
    """Golpe de susto: cluster disonante de violines + chirrido + golpe grave."""
    out = A.silencio(1.8)
    for n_, c in (("A", 0), ("A#", 0), ("B", -20), ("F", 30)):
        A.poner(out, 0, A.violin(A.f(n_, 5, c), 1.2, 1.2, vibrato=11, prof=0.03, ataque=0.005, aspereza=0.25), 1.0)
    t = A.t_(1.2)
    golpe = np.sin(2 * np.pi * 45 * t * (1 - 0.4 * t)) * np.exp(-t * 5) * 1.5
    golpe += A.filtro(rng.standard_normal(len(t)), "low", 600) * np.exp(-t * 10)
    A.poner(out, 0, golpe, 1.0)
    chirrido = A.filtro(rng.standard_normal(len(t)), "band", [2500, 7000]) * np.exp(-t * 6)
    A.poner(out, 0.02, chirrido, 0.4)
    return A.normalizar(A.reverb(out, 1.5, 0.35), 0.95)


def susto_suave():
    """Para sustos de ambiente: susurro + nota que roza."""
    out = A.silencio(2.2)
    v = A.voz(lambda tt: 180 + 30 * np.sin(tt * 9), 1.4, [(900, 300, 1.0), (2500, 500, 0.6)], aliento=2.0)
    A.poner(out, 0.0, v * np.sin(np.pi * A.t_(1.4) / 1.4), 0.5)
    A.poner(out, 0.1, A.violin(A.f("D#", 6), 1.6, 0.6, vibrato=6, ataque=0.3, aspereza=0.1), 1.0)
    return A.normalizar(A.reverb(out, 2.0, 0.5), 0.7)


def viento():
    """Ráfaga de la cueva: silbido que crece (aviso) y sopla fuerte unos segundos."""
    dur = 3.6
    t = A.t_(dur)
    envolvente = np.clip(t / 1.3, 0, 1) ** 2 * np.clip((dur - t) / 0.8, 0, 1)
    soplo = A.filtro(rng.standard_normal(len(t)), "band", [180, 1400]) * envolvente
    silbido = np.zeros_like(t)
    for f0, a in ((620, 0.5), (910, 0.3)):
        fase = 2 * np.pi * np.cumsum(f0 * (1 + 0.06 * np.sin(t * 2.3)) / A.SR)
        silbido += a * np.sin(fase)
    silbido *= A.filtro(rng.standard_normal(len(t)), "low", 30) * 4 * envolvente
    out = soplo + 0.25 * silbido
    return A.normalizar(A.reverb(out, 1.2, 0.3), 0.7)


if __name__ == "__main__":
    os.makedirs(os.path.join(A.TMP, "sfx"), exist_ok=True)
    for nombre, fn in [("piedrita", piedrita), ("campanas", campanas), ("murmullo", murmullo), ("vela", vela),
                       ("susto", susto), ("susto_suave", susto_suave), ("viento", viento)]:
        A.guardar("sfx/" + nombre, fn(), 4)
        print(nombre)
