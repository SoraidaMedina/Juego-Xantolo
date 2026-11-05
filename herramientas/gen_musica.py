"""Música de Xantolo v2: un tema original de huapango que se transforma en cada escena.

Menú: tema en menor, suave. Sierra: fragmentos desafinados. Río: el tema lento en violín solo.
Pueblo: el tema completo en mayor con jarana, huapanguera, violín a dos voces y zapateado.
Uso: python gen_musica.py <carpeta assets/audio> <carpeta temporal>
"""
import sys
import numpy as np

import gen_audio as A  # instrumentos base (cuerda, violin, reverb, etc.)

rng = np.random.default_rng(1101)
MENOR = [0, 2, 3, 5, 7, 8, 11]   # re menor armónico
MAYOR = [0, 2, 4, 5, 7, 9, 11]
TONICA = A.NOTAS["D"] + 12        # Re5 (semitonos desde La4)

# Tema original: (grado, octava, corcheas). Grado 1 = Re.
FRASE_A = [(5, -1, 3), (1, 0, 1), (2, 0, 1), (3, 0, 1), (2, 0, 2), (1, 0, 1), (7, -1, 3),
           (1, 0, 1), (2, 0, 1), (3, 0, 1), (4, 0, 2), (3, 0, 1), (2, 0, 6)]
FRASE_A2 = [(5, -1, 3), (1, 0, 1), (2, 0, 1), (3, 0, 1), (4, 0, 2), (3, 0, 1), (2, 0, 3),
            (3, 0, 1), (2, 0, 1), (1, 0, 1), (7, -1, 2), (2, 0, 1), (1, 0, 6)]
FRASE_B = [(5, 0, 2), (6, 0, 1), (5, 0, 2), (3, 0, 1), (4, 0, 2), (5, 0, 1), (4, 0, 2), (2, 0, 1),
           (3, 0, 1), (4, 0, 1), (3, 0, 1), (2, 0, 1), (1, 0, 1), (7, -1, 1), (1, 0, 3), (5, -1, 3)]
ARMONIA = {"A": ["I", "V7", "I", "V7"], "A2": ["I", "IV", "V7", "I"], "B": ["I", "V7", "V7", "I"]}
FRASES = {"A": FRASE_A, "A2": FRASE_A2, "B": FRASE_B}


def altura(grado, octava, escala, cents=0.0):
    semis = TONICA + escala[(grado - 1) % 7] + 12 * (octava + (grado - 1) // 7)
    return A.nota(semis + cents / 100)


def acorde_de(funcion, escala):
    raiz = {"I": 0, "IV": 5, "V7": 7}[funcion]
    tercera = escala[2] if funcion != "V7" else 4
    tipo = [0, 7, 12, 12 + tercera, 19] if funcion != "V7" else [0, 7, 10, 16, 19]
    base = TONICA - 24 + raiz
    return [A.nota(base + i) for i in tipo]


def jarana(acorde, dur, abajo, apagado, vol, desafine=0.0):
    """Rasgueo; el 'apagón' es un golpe seco con la palma (percusivo, casi sin nota)."""
    out = A.silencio(dur + 0.25)
    orden = acorde if abajo else acorde[::-1]
    for i, fr in enumerate(orden):
        c = desafine * rng.uniform(-1, 1)
        if apagado:
            s = A.cuerda(fr * 2 ** (c / 1200), 0.12, brillo=1.2, decaimiento=30.0, armonicos=8)
        else:
            s = A.cuerda(fr * 2 ** (c / 1200), dur, brillo=0.95, decaimiento=2.6)
            s += A.cuerda(fr * 2 * 2 ** ((c + 4) / 1200), dur, brillo=0.6, decaimiento=3.4) * 0.35  # órdenes dobles
        A.poner(out, i * (0.008 if apagado else 0.011), s, 0.2)
    if apagado:
        t = A.t_(0.06)
        A.poner(out, 0, A.filtro(rng.standard_normal(len(t)) * np.exp(-t * 90), "band", [800, 5000]), 0.35)
    return out * vol


def rasgueo_compas(buf, t0, corchea, acorde, compas_n, vol, desafine=0.0, huecos=0.0):
    """Sesquiáltera: alterna 6/8 (acentos 1 y 4) con 3/4 (acentos 1, 3 y 5)."""
    if compas_n % 2 == 0:
        patron = [(0, True, False, 1.0), (1, False, True, 0.5), (2, True, False, 0.6),
                  (3, True, False, 0.95), (4, False, True, 0.5), (5, False, False, 0.55)]
    else:
        patron = [(0, True, False, 1.0), (1, False, True, 0.45), (2, True, False, 0.9),
                  (3, False, True, 0.45), (4, True, False, 0.9), (5, False, False, 0.5)]
    for paso, abajo, apagado, acento in patron:
        if huecos and rng.random() < huecos:
            continue
        t = t0 + paso * corchea + rng.normal(0, 0.004 + huecos * 0.03)
        A.poner(buf, t, jarana(acorde, 0.6, abajo, apagado, vol * acento, desafine), 1.0)


def huapanguera(buf, t0, corchea, acorde, vol):
    raiz = acorde[0]
    for paso, mult, v in ((0, 1.0, 1.0), (3, 1.5, 0.7), (5, 2.0, 0.45)):
        A.poner(buf, t0 + paso * corchea, A.cuerda(raiz * mult, 1.1, 0.55, 1.7, 9), vol * v)


def violin_frase(buf, t0, corchea, frase, escala, vol, segunda_voz=False, desafine=0.0,
                 estirar=1.0, adornos=True, saltar=0.0, vib=5.6):
    t = t0
    for grado, octava, cor in frase:
        dur = cor * corchea * estirar
        if saltar and rng.random() < saltar:
            t += dur
            continue
        cents = desafine * rng.uniform(-1, 1)
        fr = altura(grado, octava, escala, cents)
        nota = A.violin(fr, dur * 0.97, vol, vibrato=vib, prof=0.006 + desafine / 6000,
                        ataque=0.03 if estirar < 2 else 0.5, aspereza=desafine / 2000)
        if adornos and cor >= 2:  # nota de adorno: un grado arriba, muy rápida (típico del violín huasteco)
            gracia = A.violin(altura(grado + 1, octava, escala, cents), 0.05, vol * 0.8, ataque=0.005)
            A.poner(buf, t - 0.04, gracia, 1.0)
        A.poner(buf, t, nota, 1.0)
        if segunda_voz:  # terceras abajo, como los dos violines en las fiestas
            A.poner(buf, t, A.violin(altura(grado - 2, octava, escala, cents), dur * 0.97, vol * 0.5,
                                     vibrato=vib - 0.4, ataque=0.04), 1.0)
        t += dur
    return t


def tarima(buf, t0, corchea, vol):
    for paso, v in ((0, 1.0), (1, 0.5), (2, 0.7), (3, 1.0), (4, 0.5), (5, 0.7)):
        A.poner(buf, t0 + paso * corchea, A.golpe_tarima(v, rng.uniform(150, 190)), vol)


def tocar(buf, t0, corchea, secciones, escala, vol_jarana=0.5, bajo=True, violin=True, segunda=False,
          zapateado=False, desafine=0.0, huecos=0.0, vol_violin=0.85):
    n = 0
    for sec in secciones:
        for k, funcion in enumerate(ARMONIA[sec]):
            ac = acorde_de(funcion, escala)
            tc = t0 + n * 6 * corchea
            rasgueo_compas(buf, tc, corchea, ac, n, vol_jarana, desafine, huecos)
            if bajo:
                huapanguera(buf, tc, corchea, ac, 0.5)
            if zapateado:
                tarima(buf, tc, corchea, 0.22)
            n += 1
        if violin:
            violin_frase(buf, t0 + (n - 4) * 6 * corchea, corchea, FRASES[sec], escala, vol_violin,
                         segunda_voz=segunda, desafine=desafine)
    return t0 + n * 6 * corchea


def musica_menu():
    corchea = 60 / 92 / 2
    dur = 16 * 6 * corchea * 2 + 0.5
    buf = A.silencio(dur)
    t = 0.0
    for vuelta in range(2):
        t = tocar(buf, t, corchea, ["A", "A2", "B", "A2"], MENOR, vol_jarana=0.4, bajo=True,
                  violin=vuelta == 1 or True, vol_violin=0.7)
    buf += A.viento(dur, 0.18, 4) + A.crepitar(dur, 3)
    return A.fundido_bucle(A.normalizar(A.reverb(buf, 2.2, 0.35), 0.7))


def musica_sierra():
    dur = 60.0
    buf = A.silencio(dur)
    corchea = 60 / 104 / 2
    t = 2.0
    while t < dur - 8:
        sec = rng.choice(["A", "A2", "B"])
        if rng.random() < 0.55:  # jarana desafinada que aparece y se corta
            fin = tocar(buf, t, corchea, [sec], MENOR, vol_jarana=0.4, bajo=False, violin=False,
                        desafine=60, huecos=0.35)
        else:  # el tema, roto, en violín desafinado
            fin = violin_frase(buf, t, corchea * 1.3, FRASES[sec][: rng.integers(3, 7)], MENOR, 0.55,
                               desafine=45, saltar=0.25, vib=4.5)
        t = fin + rng.uniform(3.0, 7.0)
    buf += A.viento(dur, 0.6, 5) + A.grillos(dur, 6)
    return A.fundido_bucle(A.normalizar(A.reverb(buf, 2.6, 0.45), 0.6))


def musica_rio():
    dur = 64.0
    buf = A.silencio(dur)
    corchea = 60 / 104 / 2
    t = 2.0
    for sec in ["A", "A2"]:
        t = violin_frase(buf, t, corchea, FRASES[sec], MENOR, 0.8, estirar=3.2, adornos=False,
                         desafine=18, vib=4.0)
        t += 2.0
    # una segunda voz que roza (segunda menor) en algunas notas largas
    for k in range(6):
        tt = rng.uniform(4, dur - 8)
        A.poner(buf, tt, A.violin(altura(rng.integers(1, 6), 0, MENOR, 100), 4.0, 0.3, vibrato=3.6, ataque=1.2), 1.0)
    buf = A.reverb(buf, 3.2, 0.5)
    buf += A.agua(dur)
    return A.fundido_bucle(A.normalizar(buf, 0.6))


def musica_pueblo():
    corchea = 60 / 116 / 2
    compas = 6 * corchea
    dur = (4 + 16 + 16) * compas + 1.0
    buf = A.silencio(dur)
    # Resurge poco a poco: 4 compases de jarana sola, luego todo
    t = 0.0
    for n in range(4):
        rasgueo_compas(buf, t + n * compas, corchea, acorde_de("I", MAYOR), n, 0.3 + n * 0.07)
    t = 4 * compas
    t = tocar(buf, t, corchea, ["A", "A2", "B", "A2"], MAYOR, vol_jarana=0.5, bajo=True, segunda=False,
              zapateado=False, vol_violin=0.8)
    t = tocar(buf, t, corchea, ["A", "A2", "B", "A2"], MAYOR, vol_jarana=0.55, bajo=True, segunda=True,
              zapateado=True, vol_violin=0.85)
    return A.fundido_bucle(A.normalizar(A.reverb(buf, 1.4, 0.25), 0.75))


if __name__ == "__main__":
    import os
    for nombre, fn in [("menu", musica_menu), ("sierra", musica_sierra), ("rio", musica_rio),
                       ("pueblo", musica_pueblo)]:
        A.guardar(os.path.join("musica", nombre), fn(), 4)
        print("musica", nombre)
