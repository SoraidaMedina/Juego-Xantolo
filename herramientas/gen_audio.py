"""Sintetiza la música (huapango deconstruido) y los efectos de sonido de Xantolo.
Instrumentos: jarana (rasgueo), quinta huapanguera (bajos), violín, tarima (zapateado).
Todo se genera por síntesis aditiva; no usa grabaciones.
"""
import os
import subprocess
import sys
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

SR = 44100
OUT = sys.argv[1]
TMP = sys.argv[2]
rng = np.random.default_rng(2026)


# ---------------- utilidades ----------------
def silencio(seg):
    return np.zeros(int(seg * SR))


def t_(seg):
    return np.arange(int(seg * SR)) / SR


def nota(n):
    """n = semitonos desde La4 (440 Hz)."""
    return 440.0 * 2 ** (n / 12)


NOTAS = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}


def f(nombre, octava=4, cents=0.0):
    return nota(NOTAS[nombre] + (octava - 4) * 12 + cents / 100)


def filtro(x, tipo, corte, orden=2):
    sos = butter(orden, corte, btype=tipo, fs=SR, output="sos")
    return sosfilt(sos, x)


def reverb(x, seg=1.6, mezcla=0.3, brillo=3000):
    n = int(seg * SR)
    ir = rng.standard_normal(n) * np.exp(-np.linspace(0, 7, n))
    ir = filtro(ir, "low", brillo)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    mojado = fftconvolve(x, ir)[: len(x)]
    return x * (1 - mezcla) + mojado * mezcla * 0.8


def poner(buf, inicio, sig, vol=1.0):
    i = int(inicio * SR)
    if i < 0:
        sig, i = sig[-i:], 0
    if i >= len(buf):
        return
    sig = sig[: len(buf) - i]
    buf[i: i + len(sig)] += sig * vol


def normalizar(x, pico=0.85):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * pico


def fundido_bucle(x, seg=0.08):
    """Suaviza inicio y final para que el bucle no truene."""
    n = int(seg * SR)
    x = x.copy()
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x


def guardar(nombre, x, calidad=4):
    wav = os.path.join(TMP, nombre + ".wav")
    from scipy.io import wavfile
    wavfile.write(wav, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
    ogg = os.path.join(OUT, nombre + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", str(calidad), ogg], check=True)


# ---------------- instrumentos ----------------
def cuerda(frec, dur=1.6, brillo=1.0, decaimiento=2.2, armonicos=14):
    """Cuerda pulsada (jarana / huapanguera) por síntesis aditiva."""
    t = t_(dur)
    s = np.zeros_like(t)
    for k in range(1, armonicos + 1):
        if frec * k > SR / 2.2:
            break
        amp = (1.0 / k ** (1.6 - 0.5 * brillo)) * (0.6 + 0.4 * np.sin(k * 1.7))  # punto de pulsación
        s += amp * np.sin(2 * np.pi * frec * k * t + rng.uniform(0, 6.28)) * np.exp(-t * decaimiento * (1 + 0.35 * k))
    ataque = int(0.003 * SR)
    s[:ataque] *= np.linspace(0, 1, ataque)
    s += rng.standard_normal(len(t)) * np.exp(-t * 80) * 0.15 * brillo  # ruido del plectro
    return s


def rasgueo(acorde, dur=0.9, abajo=True, desafine=0.0, vol=1.0, brillo=1.0):
    """Jarana: 5 órdenes rasgueados casi a la vez."""
    notas_ = acorde if abajo else acorde[::-1]
    out = silencio(dur + 0.2)
    for i, fr in enumerate(notas_):
        c = desafine * rng.uniform(-1, 1)
        s = cuerda(fr * 2 ** (c / 1200), dur, brillo=brillo, decaimiento=3.0)
        poner(out, i * 0.012, s, 0.22)
    return out * vol


def violin(frec, dur, vol=1.0, vibrato=5.5, prof=0.006, desafine_glide=0.0, ataque=0.12, aspereza=0.0):
    t = t_(dur)
    vib = 1 + prof * np.sin(2 * np.pi * vibrato * t) * np.clip(t / 0.4, 0, 1)
    glide = 1 + desafine_glide * t / dur
    fase = 2 * np.pi * np.cumsum(frec * vib * glide) / SR
    s = np.zeros_like(t)
    for k in range(1, 16):
        if frec * k > SR / 2.2:
            break
        formante = 1.0 + 1.5 * np.exp(-((frec * k - 2800) / 1200) ** 2) + 0.8 * np.exp(-((frec * k - 1000) / 400) ** 2)
        s += np.sin(k * fase) / k * formante
    s += rng.standard_normal(len(t)) * (0.03 + aspereza) * (1 + np.sin(2 * np.pi * 7 * t) * 0.3)  # arco
    env = np.minimum(1, t / ataque) * np.minimum(1, (dur - t) / 0.15)
    env = np.clip(env, 0, 1)
    return filtro(s * env, "low", 6000) * 0.25 * vol


def golpe_tarima(vol=1.0, tono=180):
    t = t_(0.25)
    s = np.sin(2 * np.pi * tono * t * (1 - t)) * np.exp(-t * 30) + rng.standard_normal(len(t)) * np.exp(-t * 60) * 0.5
    return filtro(s, "low", 1800) * vol


def viento(seg, fuerza=1.0, semilla=0):
    r = np.random.default_rng(semilla)
    n = r.standard_normal(int(seg * SR))
    n = filtro(n, "band", [180, 900])
    lfo = np.interp(np.arange(len(n)), np.linspace(0, len(n), 12), r.uniform(0.2, 1.0, 12))
    return n * lfo * 0.25 * fuerza


def grillos(seg, semilla=1):
    r = np.random.default_rng(semilla)
    out = silencio(seg)
    t0 = 0.0
    while t0 < seg:
        t = t_(0.06)
        chirp = np.sin(2 * np.pi * 4200 * t) * np.sin(np.pi * t / 0.06) ** 2
        for k in range(3):
            poner(out, t0 + k * 0.08, chirp, 0.04 * r.uniform(0.5, 1))
        t0 += r.uniform(0.6, 2.2)
    return out


def agua(seg, semilla=2):
    r = np.random.default_rng(semilla)
    n = filtro(r.standard_normal(int(seg * SR)), "band", [300, 2500]) * 0.18
    mod = 0.6 + 0.4 * np.sin(2 * np.pi * 0.13 * t_(seg)) * np.sin(2 * np.pi * 0.07 * t_(seg) + 1)
    out = n * mod
    t0 = 0.0
    while t0 < seg:  # burbujas / gotas
        t = t_(0.08)
        fr = r.uniform(600, 1400)
        gota = np.sin(2 * np.pi * fr * t * (1 + t * 6)) * np.exp(-t * 50)
        poner(out, t0, gota, 0.08)
        t0 += r.uniform(0.3, 1.6)
    return out


def crepitar(seg, densidad=6, semilla=3):
    r = np.random.default_rng(semilla)
    out = silencio(seg)
    for _ in range(int(seg * densidad)):
        t = t_(0.01)
        poner(out, r.uniform(0, seg), r.standard_normal(len(t)) * np.exp(-t * 600), r.uniform(0.02, 0.08))
    return filtro(out, "high", 1500)


# ---------------- acordes ----------------
def acorde(raiz, tipo="M", oct_=3):
    base = NOTAS[raiz] + (oct_ - 4) * 12
    intervalos = {"M": [0, 7, 12, 16, 19], "m": [0, 7, 12, 15, 19], "7": [0, 7, 10, 16, 19]}[tipo]
    return [nota(base + i + 12) for i in intervalos]


def patron_huapango(buf, inicio, compases, acordes_, bpm=108, vol=1.0, desafine=0.0, huecos=0.0, bajo=True):
    """Sesquiáltera de huapango: 6/8 con rasgueos acentuados 1-4 y contratiempos."""
    corchea = 60 / bpm / 2
    patron = [(0, True, 1.0), (1, False, 0.5), (2, True, 0.7), (3, True, 1.0), (4, False, 0.5), (5, False, 0.6)]
    for c in range(compases):
        ac = acordes_[c % len(acordes_)]
        if huecos and rng.random() < huecos:
            continue  # se corta: silencio
        for paso, abajo, acento in patron:
            if huecos and rng.random() < huecos * 0.4:
                continue
            t0 = inicio + (c * 6 + paso) * corchea + rng.normal(0, 0.006 + huecos * 0.03)
            poner(buf, t0, rasgueo(ac, 0.5 if huecos else 0.7, abajo, desafine, brillo=0.9), vol * acento)
        if bajo:  # quinta huapanguera
            raiz = ac[0] / 2
            poner(buf, inicio + c * 6 * corchea, cuerda(raiz, 1.2, 0.5, 1.6, 8), vol * 0.55)
            poner(buf, inicio + (c * 6 + 3) * corchea, cuerda(raiz * 1.5, 1.0, 0.5, 1.8, 8), vol * 0.4)


# ---------------- música ----------------
def musica_menu():
    dur = 48.0
    buf = silencio(dur)
    acs = [acorde("D", "m"), acorde("A", "7", 2), acorde("D", "m"), acorde("G", "m"),
           acorde("D", "m"), acorde("A", "7", 2), acorde("D", "m"), acorde("D", "m")]
    patron_huapango(buf, 0.0, 16, acs, bpm=92, vol=0.55, bajo=True)
    mel = [("A", 4, 2.6), ("F", 4, 1.3), ("E", 4, 1.3), ("D", 4, 2.6), ("C#", 4, 2.6),
           ("D", 4, 1.3), ("E", 4, 1.3), ("F", 4, 2.6), ("E", 4, 3.9), ("A", 4, 2.6), ("G", 4, 1.3),
           ("F", 4, 1.3), ("E", 4, 2.6), ("D", 4, 5.2)]
    t0 = 7.8
    for n_, o, d in mel:
        poner(buf, t0, violin(f(n_, o), d * 0.95, 0.9), 1.0)
        t0 += d
    buf += viento(dur, 0.25, 4) + crepitar(dur, 3)
    return fundido_bucle(normalizar(reverb(buf, 2.0, 0.35), 0.7))


def musica_sierra():
    dur = 56.0
    buf = silencio(dur)
    acs = [acorde("A", "m"), acorde("E", "7", 2), acorde("A", "m"), acorde("D", "m")]
    # Jarana desafinada que aparece y se corta
    t0 = 1.5
    while t0 < dur - 6:
        compases = int(rng.integers(1, 4))
        patron_huapango(buf, t0, compases, acs, bpm=int(rng.integers(96, 118)), vol=0.45, desafine=55, huecos=0.35, bajo=False)
        t0 += compases * 6 * 60 / 104 / 2 + rng.uniform(3.0, 7.0)
    buf += viento(dur, 0.6, 5) + grillos(dur, 6)
    return fundido_bucle(normalizar(reverb(buf, 2.5, 0.45), 0.6))


def musica_rio():
    dur = 60.0
    buf = silencio(dur)
    # Violín solo, notas largas en menor con disonancias (segundas menores, tritonos)
    frase = [("E", 4, 5.5, 0), ("F", 4, 4.0, -25), ("E", 4, 3.0, 10), ("A#", 3, 6.0, 0),
             ("A", 3, 4.0, 0), ("C", 4, 5.0, -15), ("B", 3, 6.5, 0), ("E", 4, 8.0, -30)]
    t0 = 2.0
    for n_, o, d, c in frase:
        poner(buf, t0, violin(f(n_, o, c), d, 0.9, vibrato=4.2, prof=0.009, desafine_glide=-0.004, ataque=0.8, aspereza=0.02), 1.0)
        if rng.random() < 0.5:  # segunda voz que roza
            poner(buf, t0 + 1.2, violin(f(n_, o, c + 100), d * 0.6, 0.45, vibrato=3.7, ataque=1.0), 1.0)
        t0 += d + rng.uniform(0.5, 2.0)
    buf = reverb(buf, 3.0, 0.5)
    buf += agua(dur)
    return fundido_bucle(normalizar(buf, 0.6))


def musica_monte():
    dur = 52.0
    buf = silencio(dur)
    # Zumbido grave y percusión sutil separada por silencios largos
    t = t_(dur)
    dron = (np.sin(2 * np.pi * 55 * t) + 0.5 * np.sin(2 * np.pi * 58.3 * t)) * 0.08
    dron *= 0.5 + 0.5 * np.sin(2 * np.pi * t / 13.0) ** 2
    buf += dron
    t0 = 3.0
    while t0 < dur - 3:
        golpes = int(rng.integers(2, 5))
        for k in range(golpes):
            poner(buf, t0 + k * 0.42, golpe_tarima(0.6, rng.uniform(70, 110)), 1.0)
        t0 += golpes * 0.42 + rng.uniform(5.0, 9.0)
    buf += viento(dur, 0.35, 7)
    return fundido_bucle(normalizar(reverb(buf, 2.8, 0.4, 1500), 0.55))


def musica_pueblo():
    dur = 60.0
    buf = silencio(dur)
    acs = [acorde("D", "M"), acorde("A", "7", 2), acorde("D", "M"), acorde("G", "M"),
           acorde("D", "M"), acorde("A", "7", 2), acorde("D", "M"), acorde("D", "M")]
    bpm = 112
    corchea = 60 / bpm / 2
    comp = 6 * corchea
    total = int(dur / comp)
    # Resurge poco a poco: primero jarana sola, luego huapanguera, luego violín y tarima
    for c in range(total):
        vol = min(1.0, 0.3 + c / 10)
        patron_huapango(buf, c * comp, 1, [acs[c % 8]], bpm=bpm, vol=0.5 * vol, bajo=c >= 4)
        if c >= 8:
            for paso in (0, 2, 3, 5):
                poner(buf, c * comp + paso * corchea, golpe_tarima(0.25, 160), 1.0)
    mel = [("F#", 5, 1), ("E", 5, 1), ("D", 5, 1), ("A", 4, 3), ("B", 4, 1), ("C#", 5, 1), ("D", 5, 1), ("E", 5, 3),
           ("F#", 5, 1), ("G", 5, 1), ("F#", 5, 1), ("E", 5, 2), ("D", 5, 1), ("C#", 5, 3), ("E", 5, 3),
           ("D", 5, 6)]
    for vuelta in range(3):
        t0 = (8 + vuelta * 16) * comp
        for n_, o, d in mel:
            if t0 > dur - 1:
                break
            poner(buf, t0, violin(f(n_, o), d * corchea * 0.95, 0.8, vibrato=6.0, ataque=0.03), 1.0)
            t0 += d * corchea
    return fundido_bucle(normalizar(reverb(buf, 1.4, 0.25), 0.75))


# ---------------- efectos ----------------
def sfx_paso():
    t = t_(0.12)
    s = rng.standard_normal(len(t)) * np.exp(-t * 45)
    return normalizar(filtro(s, "band", [150, 1200]), 0.5)


def sfx_salto():
    t = t_(0.2)
    s = rng.standard_normal(len(t)) * np.exp(-t * 18) * np.sin(np.pi * t / 0.2)
    return normalizar(filtro(s, "band", [300, 2500]), 0.4)


def sfx_caida():
    t = t_(0.25)
    s = rng.standard_normal(len(t)) * np.exp(-t * 25) + np.sin(2 * np.pi * 90 * t) * np.exp(-t * 20)
    return normalizar(filtro(s, "low", 900), 0.7)


def sfx_recoger():
    buf = silencio(1.4)
    for i, n_ in enumerate([("D", 5), ("F#", 5), ("A", 5)]):
        poner(buf, i * 0.09, cuerda(f(*n_), 1.2, 1.0, 3.0, 10), 0.6)
    return normalizar(reverb(buf, 1.2, 0.35), 0.6)


def sfx_copal():
    t = t_(1.6)
    n = rng.standard_normal(len(t))
    barrido = np.zeros_like(n)
    for i, (a, b) in enumerate([(200, 800), (500, 1600), (900, 3000)]):
        seg = slice(i * len(t) // 3, (i + 1) * len(t) // 3)
        barrido[seg] = filtro(n, "band", [a, b])[seg]
    env = np.sin(np.pi * t / 1.6) ** 1.5
    return normalizar(reverb(barrido * env + crepitar(1.6, 25), 1.0, 0.3), 0.6)


def voz(f0, dur, formantes, aliento=0.15, vib=0.0):
    t = t_(dur)
    f0t = f0(t) if callable(f0) else np.full_like(t, f0)
    if vib:
        f0t = f0t * (1 + vib * np.sin(2 * np.pi * 5.5 * t))
    fase = 2 * np.pi * np.cumsum(f0t) / SR
    pulsos = np.zeros_like(t)
    for k in range(1, 30):
        pulsos += np.sin(k * fase) / k ** 0.8
    pulsos += rng.standard_normal(len(t)) * aliento
    s = np.zeros_like(t)
    for fc, ancho, g in formantes:
        s += filtro(pulsos, "band", [max(fc - ancho, 50), fc + ancho]) * g
    return s


def sfx_risa_chaneque():
    """'Ji-ji-ji' infantil, agudo y travieso."""
    buf = silencio(1.4)
    t0 = 0.0
    f0 = rng.uniform(520, 600)
    for i in range(int(rng.integers(5, 8))):
        d = rng.uniform(0.06, 0.09)
        sil = voz(f0 * (1 - i * 0.04), d, [(320, 80, 1.0), (2300, 300, 0.7), (3100, 300, 0.4)], aliento=0.4)
        env = np.sin(np.pi * t_(d) / d) ** 0.7
        poner(buf, t0, sil * env, 1.0)
        t0 += d + rng.uniform(0.03, 0.06)
    return normalizar(reverb(buf, 1.6, 0.45), 0.55)


def sfx_descubierta():
    """Golpe de violín disonante (segunda menor) cuando te descubren."""
    buf = silencio(1.4)
    poner(buf, 0, violin(f("E", 5), 1.1, 1.0, vibrato=9, prof=0.02, ataque=0.01, aspereza=0.1), 1.0)
    poner(buf, 0, violin(f("F", 5), 1.1, 1.0, vibrato=8, prof=0.02, ataque=0.01, aspereza=0.1), 1.0)
    return normalizar(reverb(buf, 1.4, 0.4), 0.7)


def sfx_atrapada():
    t = t_(1.6)
    golpe = np.sin(2 * np.pi * 60 * t * (1 - 0.3 * t)) * np.exp(-t * 4)
    golpe += filtro(rng.standard_normal(len(t)), "low", 400) * np.exp(-t * 8) * 0.6
    cuerdas = sum(cuerda(f(n_, 3, rng.uniform(-40, 40)), 1.6, 1.2, 1.5) for n_ in ["D", "D#", "G#"])
    return normalizar(reverb(golpe + cuerdas * 0.3, 1.8, 0.4), 0.8)


def sfx_escondite():
    t = t_(0.5)
    s = filtro(rng.standard_normal(len(t)), "band", [1500, 6000]) * np.sin(np.pi * t / 0.5) ** 2
    s *= 0.6 + 0.4 * np.sin(2 * np.pi * 23 * t)
    return normalizar(s, 0.35)


def sfx_llanto():
    """Lamento lejano de la Llorona: '¡aaay…!' que sube y cae."""
    d = 2.8
    contorno = lambda t: 330 + 160 * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 0.6 - 120 * np.clip((t - 1.8) / 1.0, 0, 1)
    s = voz(contorno, d, [(800, 150, 1.0), (1200, 200, 0.8), (2600, 300, 0.3)], aliento=0.25, vib=0.02)
    env = np.minimum(1, t_(d) / 0.4) * np.minimum(1, (d - t_(d)) / 0.8)
    return normalizar(reverb(s * env, 3.0, 0.6, 2500), 0.6)


def sfx_gruñido():
    t = t_(1.8)
    f0 = 55 + 15 * np.sin(2 * np.pi * 0.8 * t)
    s = voz(lambda tt: 55 + 15 * np.sin(2 * np.pi * 0.8 * tt), 1.8, [(300, 120, 1.0), (700, 200, 0.6)], aliento=0.8)
    s *= np.sin(np.pi * t / 1.8) ** 0.8 * (0.7 + 0.3 * np.sin(2 * np.pi * 11 * t))
    return normalizar(reverb(filtro(s, "low", 1200), 1.5, 0.3), 0.7)


def sfx_latido():
    buf = silencio(1.0)
    for t0, v in ((0, 1.0), (0.22, 0.7)):
        t = t_(0.2)
        poner(buf, t0, np.sin(2 * np.pi * 50 * t) * np.exp(-t * 25), v)
    return normalizar(filtro(buf, "low", 200), 0.8)


def sfx_ui():
    return normalizar(cuerda(f("A", 5), 0.4, 0.8, 8.0, 6), 0.35)


if __name__ == "__main__":
    os.makedirs(os.path.join(OUT, "musica"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "sfx"), exist_ok=True)
    for nombre, fn in [("menu", musica_menu), ("sierra", musica_sierra), ("rio", musica_rio),
                       ("monte", musica_monte), ("pueblo", musica_pueblo)]:
        guardar("musica/" + nombre, fn(), 3)
        print("musica", nombre)
    for nombre, fn in [("paso", sfx_paso), ("salto", sfx_salto), ("caida", sfx_caida), ("recoger", sfx_recoger),
                       ("copal", sfx_copal), ("risa_chaneque", sfx_risa_chaneque), ("descubierta", sfx_descubierta),
                       ("atrapada", sfx_atrapada), ("escondite", sfx_escondite), ("llanto", sfx_llanto),
                       ("grunido", sfx_gruñido), ("latido", sfx_latido), ("ui", sfx_ui)]:
        guardar("sfx/" + nombre, fn(), 4)
    print("sfx ok")
