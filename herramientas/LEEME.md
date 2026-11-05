# Herramientas (Python)

Scripts que generaron recursos provisionales. No los necesita el juego para correr.

- `gen_audio.py` — sintetiza la música (huapango deconstruido: jarana, violín, quinta huapanguera)
  y los efectos de sonido en `assets/audio/`. Uso: `python gen_audio.py ../assets/audio carpeta_temporal`
  (requiere numpy, scipy y ffmpeg).
- `gen_fondos.py` — compone las pantallas 1 y 3 de la Sierra a partir del fondo original.
- `gen_plataformas.py` — dibuja las rocas, el tronco y las piedras del arroyo.

Cuando el equipo tenga grabaciones reales de huapango o fondos dibujados a mano,
basta con reemplazar los archivos con el mismo nombre.
