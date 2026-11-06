"""Canción de fiesta para el final: un huapango alegre y completo, compuesto para el juego.

Re mayor, 126 bpm, sesquiáltera (6/8 y 3/4 alternados).
Forma: intro de violín · A · A' · B (8 compases) · A · A' · zapateado · A · A' · cierre.
Dos violines en terceras, jarana con apagones, quinta huapanguera y tarima.
Uso: python gen_fiesta.py <carpeta assets/audio> <carpeta temporal>
"""
import os
import sys
import numpy as np

sys.argv = sys.argv[:3]
import gen_audio as A
import gen_musica as M

M.rng = np.random.default_rng(2611)
ESC = M.MAYOR
BPM = 126
CORCHEA = 60 / BPM / 2
COMPAS = 6 * CORCHEA

# (grado, octava, corcheas). Octava 0 = alrededor de Re5; -1 = una abajo.
INTRO = [(1, -1, 1), (3, -1, 1), (5, -1, 1), (1, 0, 1), (3, 0, 1), (5, 0, 1),
         (4, 0, 1), (3, 0, 1), (2, 0, 1), (1, 0, 3)]
TEMA_A = [(5, -1, 1), (6, -1, 1), (5, -1, 1), (3, 0, 2), (2, 0, 1),
          (1, 0, 2), (7, -1, 1), (6, -1, 1), (5, -1, 2),
          (4, -1, 1), (5, -1, 1), (6, -1, 1), (7, -1, 1), (1, 0, 1), (2, 0, 1),
          (3, 0, 3), (2, 0, 3)]
TEMA_A2 = [(5, -1, 1), (6, -1, 1), (5, -1, 1), (3, 0, 2), (2, 0, 1),
           (1, 0, 2), (2, 0, 1), (3, 0, 1), (4, 0, 2),
           (3, 0, 1), (2, 0, 1), (1, 0, 1), (7, -1, 1), (6, -1, 1), (7, -1, 1),
           (1, 0, 6)]
TEMA_B = [(5, 0, 2), (5, 0, 1), (6, 0, 1), (5, 0, 1), (4, 0, 1),
          (3, 0, 2), (3, 0, 1), (4, 0, 1), (3, 0, 1), (2, 0, 1),
          (1, 0, 1), (2, 0, 1), (3, 0, 1), (4, 0, 1), (5, 0, 1), (6, 0, 1),
          (5, 0, 3), (5, -1, 3),
          (5, 0, 2), (5, 0, 1), (6, 0, 1), (5, 0, 1), (4, 0, 1),
          (3, 0, 2), (3, 0, 1), (4, 0, 1), (3, 0, 1), (2, 0, 1),
          (4, 0, 1), (3, 0, 1), (2, 0, 1), (1, 0, 1), (7, -1, 1), (2, 0, 1),
          (1, 0, 3), (1, -1, 3)]
CIERRE = [(5, -1, 1), (1, 0, 1), (3, 0, 1), (5, 0, 3), (1, 1, 6)]

ACORDES = {
    "intro": ["I", "V7"],
    "A": ["I", "I", "IV", "V7"],
    "A2": ["I", "IV", "V7", "I"],
    "B": ["I", "IV", "I", "V7", "I", "IV", "V7", "I"],
    "zapateado": ["I", "V7", "I", "V7"],
    "cierre": ["V7", "I"],
}


def acompanar(buf, t0, seccion, vol_jarana=0.5, bajo=True, tarima=False, n0=0):
    for k, funcion in enumerate(ACORDES[seccion]):
        ac = M.acorde_de(funcion, ESC)
        tc = t0 + k * COMPAS
        M.rasgueo_compas(buf, tc, CORCHEA, ac, n0 + k, vol_jarana)
        if bajo:
            M.huapanguera(buf, tc, CORCHEA, ac, 0.55)
        if tarima:
            M.tarima(buf, tc, CORCHEA, 0.3)
    return t0 + len(ACORDES[seccion]) * COMPAS


def violines(buf, t0, frase, vol=0.9, segunda=True):
    M.violin_frase(buf, t0, CORCHEA, frase, ESC, vol, segunda_voz=segunda)


def cancion():
    total = 2 + 4 + 4 + 8 + 4 + 4 + 4 + 4 + 4 + 2
    buf = A.silencio(total * COMPAS + 1.8)
    t = 0.0
    # Intro: el violín abre solo, con la jarana apenas
    violines(buf, t, INTRO, 0.95, segunda=False)
    t = acompanar(buf, t, "intro", vol_jarana=0.25, bajo=False)
    # A A'
    violines(buf, t, TEMA_A)
    t = acompanar(buf, t, "A")
    violines(buf, t, TEMA_A2)
    t = acompanar(buf, t, "A2", n0=4)
    # B: más arriba, con tarima
    violines(buf, t, TEMA_B, 0.95)
    t = acompanar(buf, t, "B", vol_jarana=0.55, tarima=True)
    # A A'
    violines(buf, t, TEMA_A)
    t = acompanar(buf, t, "A", tarima=True)
    violines(buf, t, TEMA_A2)
    t = acompanar(buf, t, "A2", tarima=True, n0=4)
    # Zapateado: se queda la jarana fuerte y la tarima, el violín descansa
    t = acompanar(buf, t, "zapateado", vol_jarana=0.65, tarima=True)
    # A A' finales con todo
    violines(buf, t, TEMA_A, 1.0)
    t = acompanar(buf, t, "A", vol_jarana=0.6, tarima=True)
    violines(buf, t, TEMA_A2, 1.0)
    t = acompanar(buf, t, "A2", vol_jarana=0.6, tarima=True, n0=4)
    # Cierre
    violines(buf, t, CIERRE, 1.0)
    t = acompanar(buf, t, "cierre", vol_jarana=0.6)
    A.poner(buf, t, M.jarana(M.acorde_de("I", ESC), 2.5, True, False, 0.9), 1.0)
    return A.fundido_bucle(A.normalizar(A.reverb(buf, 1.3, 0.22), 0.8))


def cohete():
    """Cohete de fiesta: silbido que sube y estallido."""
    sube = 0.9
    t = A.t_(sube)
    f = 900 + 2200 * (t / sube) ** 1.5
    silbido = np.sin(2 * np.pi * np.cumsum(f) / A.SR) * np.minimum(1, t / 0.05) * 0.25
    silbido += A.filtro(np.random.default_rng(1).standard_normal(len(t)), "band", [2000, 6000]) * 0.08
    t2 = A.t_(1.4)
    estallido = A.filtro(np.random.default_rng(2).standard_normal(len(t2)), "low", 1800) * np.exp(-t2 * 5)
    estallido += np.sin(2 * np.pi * 70 * t2) * np.exp(-t2 * 9) * 0.8
    out = A.silencio(sube + 1.6)
    A.poner(out, 0, silbido, 1.0)
    A.poner(out, sube, estallido, 1.0)
    return A.normalizar(A.reverb(out, 2.0, 0.4), 0.7)


if __name__ == "__main__":
    A.guardar(os.path.join("musica", "fiesta"), cancion(), 5)
    A.guardar(os.path.join("sfx", "cohete"), cohete(), 4)
    print("ok")
