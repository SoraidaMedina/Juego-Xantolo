# Herramientas (Python)

Scripts que generaron recursos provisionales. No los necesita el juego para correr.

- `gen_audio.py` — sintetiza la música (huapango deconstruido: jarana, violín, quinta huapanguera)
  y los efectos de sonido en `assets/audio/`. Uso: `python gen_audio.py ../assets/audio carpeta_temporal`
  (requiere numpy, scipy y ffmpeg).
- `gen_fondos.py` — compone las pantallas 1 y 3 de la Sierra a partir del fondo original.
- `gen_plataformas.py` — dibuja las rocas, el tronco y las piedras del arroyo.
- `gen_hud.py` — dibuja los íconos del HUD en `assets/hud/` (veladoras de vida, piezas de la
  ofrenda, talismanes, estados y el marco bordado). Cada ícono es un mapa de letras dentro
  del script: cambias una letra y vuelves a correrlo. Uso: `python gen_hud.py ../assets/hud`
- `gen_nivel1.py` — arma `Nivel1Sierra.tscn` (rocas, chaneques, objetos y el pasaje oculto del copal).
- `gen_cueva.py` — dibuja la Cueva del abuelo: los fondos de sus dos pantallas, el balero y los nueve
  recuerdos sin texto (teatro de sombras) en `assets/cueva/`.
- `gen_nivel4.py` — arma `Nivel4Cueva.tscn` (abismos, rocas, corrientes de aire, trampa y recuerdos).
- `gen_rio.py` — dibuja los fondos de los dos tramos nuevos del Río (la orilla y los rápidos) a partir
  de `rio_llorona_bg.png`. Uso: `python gen_rio.py ../assets/fondos ../assets/objetos` (también dibuja la mata de los escondites)
- `gen_monte.py` — dibuja el fondo de la ladera (primer escenario del Monte del Nahual) a partir de
  `monte_nahual_bg.png`. Uso: `python gen_monte.py ../assets/fondos`
- `gen_sfx_extra.py` — además de sus efectos, sintetiza `viento.ogg` (las ráfagas de la cueva).

Cuando el equipo tenga grabaciones reales de huapango o fondos dibujados a mano,
basta con reemplazar los archivos con el mismo nombre.
