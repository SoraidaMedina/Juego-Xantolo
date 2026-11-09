"""Genera scenes/niveles/Nivel1Sierra.tscn: la Sierra en 3 pantallas de cámara fija.

Medidas: pantalla 1152x648, piso en y=560. Xochik salta ~62 px de alto y ~105 px de largo,
así que cada escalón de roca sube 46 px como máximo.
Uso: python gen_nivel1.py ../scenes/niveles/Nivel1Sierra.tscn
"""
import sys

ANCHO = 1152
PISO = 560
P = [0, ANCHO, ANCHO * 2]           # inicio x de cada pantalla
ESC_FONDO = 0.844                     # 1376 px -> 1161 px
ARROYO = (P[2] + 567, P[2] + 803)     # hueco del arroyo en la pantalla 3

ext, sub, nodos = [], [], []


def recurso(tipo, ruta, uid=None):
    rid = f"{len(ext) + 1}_r"
    u = f' uid="{uid}"' if uid else ""
    ext.append(f'[ext_resource type="{tipo}"{u} path="{ruta}" id="{rid}"]')
    return rid


def forma_rect(w, h):
    sid = f"Rect_{len(sub) + 1}"
    sub.append(f'[sub_resource type="RectangleShape2D" id="{sid}"]\nsize = Vector2({w}, {h})')
    return sid


def nodo(texto):
    nodos.append(texto.strip("\n"))


R_SCRIPT = recurso("Script", "res://nivel_1_sierra.gd", "uid://d3e0nxsmrjk5r")
R_F1 = recurso("Texture2D", "res://assets/fondos/sierra_1_canaveral.png")
R_F2 = recurso("Texture2D", "res://assets/fondos/La_Sierra_de_los_Chaneques.png", "uid://b506hwkm5cvwj")
R_F3 = recurso("Texture2D", "res://assets/fondos/sierra_3_cempasuchil.png")
R_XOCHIK = recurso("PackedScene", "res://scenes/personajes/Xochik.tscn", "uid://2mliplafc3uu")
R_CHICO = recurso("PackedScene", "res://scenes/personajes/Chicomexochitl.tscn", "uid://b8nduubajhyl7")
R_CHANEQUE = recurso("PackedScene", "res://scenes/personajes/chaneque.tscn", "uid://dsohss617q4dj")
R_OBJ = recurso("PackedScene", "res://scenes/objeto_ofrenda.tscn")
R_ESCONDITE = recurso("PackedScene", "res://scenes/escondite.tscn")
R_PLAT = recurso("PackedScene", "res://scenes/plataforma.tscn")
R_AGUA = recurso("Script", "res://script/agua.gd")
R_PASAJE = recurso("Script", "res://script/pasaje_oculto.gd")
R_VIDA = recurso("Texture2D", "res://assets/hud/vida.png")
T = {
    "vela": recurso("Texture2D", "res://assets/objetos/vela2.png", "uid://cb1n100qh4ce2"),
    "flor": recurso("Texture2D", "res://assets/objetos/flor_cempasuchil.png", "uid://db24rsa2a3ihc"),
    "copal": recurso("Texture2D", "res://assets/objetos/copal.png", "uid://bodpu73f5uhdv"),
    "petalos": recurso("Texture2D", "res://assets/objetos/petalos.png", "uid://buiru4pr2l80t"),
}
for _n in ("arco_xantolo", "roca_baja", "roca_media", "roca_alta", "tronco", "piedra_rio"):
    T[_n] = recurso("Texture2D", f"res://assets/sierra/{_n}.png")
# Rocas sólidas: (ancho de colisión, alto donde se para Xochik, alto del sprite)
ROCA = {
    "roca_baja": (90, 46, 54),
    "roca_media": (80, 92, 100),
    "roca_alta": (72, 138, 146),
    "tronco": (164, 44, 50),
}

nodo(f'''[node name="Nivel1Sierra" type="Node2D"]
script = ExtResource("{R_SCRIPT}")''')

# ---------- Fondos (uno por pantalla) ----------
for i, r in enumerate([R_F1, R_F2, R_F3]):
    nodo(f'''[node name="Fondo{i + 1}" type="Sprite2D" parent="."]
z_index = -10
texture_filter = 1
position = Vector2({P[i]}, 0)
scale = Vector2({ESC_FONDO}, {ESC_FONDO})
texture = ExtResource("{r}")
centered = false''')

# ---------- Suelo, paredes y arroyo ----------
nodo('[node name="Suelo" type="StaticBody2D" parent="."]')
for i, (a, b) in enumerate([(0, ARROYO[0]), (ARROYO[1], ANCHO * 3)]):
    s = forma_rect(b - a, 40)
    nodo(f'''[node name="Tramo{i + 1}" type="CollisionShape2D" parent="Suelo"]
position = Vector2({(a + b) / 2}, {PISO + 20})
shape = SubResource("{s}")''')
s = forma_rect(40, 900)
nodo(f'''[node name="ParedIzq" type="CollisionShape2D" parent="Suelo"]
position = Vector2(-20, 200)
shape = SubResource("{s}")''')
nodo(f'''[node name="ParedDer" type="CollisionShape2D" parent="Suelo"]
position = Vector2({ANCHO * 3 + 20}, 200)
shape = SubResource("{s}")''')
s = forma_rect(ARROYO[1] - ARROYO[0] + 20, 60)
nodo(f'''[node name="Arroyo" type="Area2D" parent="."]
position = Vector2({(ARROYO[0] + ARROYO[1]) / 2}, {PISO + 60})
script = ExtResource("{R_AGUA}")''')
nodo(f'''[node name="CollisionShape2D" type="CollisionShape2D" parent="Arroyo"]
shape = SubResource("{s}")''')


def roca(nombre, tipo, x):
    """Roca sólida apoyada en el piso: bloquea el paso, hay que saltar encima."""
    w, alto, alto_sprite = ROCA[tipo]
    sid = forma_rect(w, alto)
    nodo(f'''[node name="{nombre}" type="StaticBody2D" parent="."]
position = Vector2({x}, {PISO})''')
    nodo(f'''[node name="Sprite2D" type="Sprite2D" parent="{nombre}"]
texture_filter = 1
position = Vector2(0, {-alto_sprite / 2 + 2})
texture = ExtResource("{T[tipo]}")''')
    nodo(f'''[node name="CollisionShape2D" type="CollisionShape2D" parent="{nombre}"]
position = Vector2(0, {-alto / 2})
shape = SubResource("{sid}")''')


def piedra(nombre, x, recorrido=0.0, y=PISO + 9, padre="."):
    """Piedra del arroyo: flota y se mece; se sube desde abajo. Su superficie queda en y - 13."""
    nodo(f'''[node name="{nombre}" parent="{padre}" instance=ExtResource("{R_PLAT}")]
position = Vector2({x}, {y})
textura = ExtResource("{T['piedra_rio']}")
escala = 1.0
tamano_colision = Vector2(52, 12)
ajuste_colision_y = -7.0
flote = 2.5
recorrido_x = {recorrido}''')


def decorado(nombre, tipo, x, z=-1):
    nodo(f'''[node name="{nombre}" type="Sprite2D" parent="."]
z_index = {z}
texture_filter = 1
position = Vector2({x}, {PISO - 190 + 4})
texture = ExtResource("{T[tipo]}")''')


def objeto(nombre, tipo, x, y):
    nodo(f'''[node name="{nombre}" parent="." instance=ExtResource("{R_OBJ}")]
position = Vector2({x}, {y})
tipo = "{tipo}"
textura = ExtResource("{T[tipo]}")
reaparece = false''')


def chaneque(nombre, x, patrulla, extra=""):
    nodo(f'''[node name="{nombre}" parent="." instance=ExtResource("{R_CHANEQUE}")]
position = Vector2({x}, 495)
distancia_patrulla = {patrulla}{extra}''')


def arbusto(nombre, x):
    nodo(f'''[node name="{nombre}" parent="." instance=ExtResource("{R_ESCONDITE}")]
position = Vector2({x}, 510)''')


# ---------- Personajes ----------
nodo(f'''[node name="Xochik" parent="." instance=ExtResource("{R_XOCHIK}")]
position = Vector2(110, 480)''')
nodo(f'''[node name="Chicomexochitl" parent="." instance=ExtResource("{R_CHICO}")]
position = Vector2(190, 400)''')

# ---------- Pantalla 1: la vereda del cañaveral (aprender sin peligro) ----------
# Las rocas forman escalera de los DOS lados (pirámide): siempre se puede regresar.
decorado("ArcoXantolo", "arco_xantolo", 470)
# Entre el tronco y la roca queda piso libre de sobra (Xochik mide 36 px de ancho):
# un hueco más angosto que ella la dejaba atorada sobre las dos esquinas.
roca("P1_Tronco", "tronco", 680)                 # saltar por encima
roca("P1_RocaBaja", "roca_baja", 880)            # escalón 1
roca("P1_RocaMedia", "roca_media", 965)          # escalón 2, con copal arriba
roca("P1_RocaBaja2", "roca_baja", 1050)          # escalón de bajada (y de regreso)
objeto("Copal1", "copal", 965, PISO - 92 - 36)
# Pasaje de las ánimas: piedras invisibles sobre la roca del copal. Solo motas tenues lo delatan;
# al quemar copal [Q] aparecen y llevan a una veladora (una vida más).
PASAJE = (960, 380)
nodo(f'''[node name="PasajeOculto" type="Node2D" parent="."]
position = Vector2({PASAJE[0]}, {PASAJE[1]})
script = ExtResource("{R_PASAJE}")
zona_pista = Vector2(260, 170)''')
for _i, (_x, _sup) in enumerate([(1058, 420), (968, 372), (878, 324)]):
    piedra(f"PiedraAnima{_i + 1}", _x - PASAJE[0], y=_sup + 13 - PASAJE[1], padre="PasajeOculto")
nodo(f'''[node name="Veladora" parent="." instance=ExtResource("{R_OBJ}")]
position = Vector2(878, 288)
tipo = "veladora"
textura = ExtResource("{R_VIDA}")
escala = 2.0
reaparece = false''')

# ---------- Pantalla 2: el bosque de los chaneques ----------
b = P[1]
objeto("Copal2", "copal", b + 130, 510)
arbusto("P2_Arbusto1", b + 270)
chaneque("P2_Chaneque1", b + 430, 110)          # cuida el paso hacia la pirámide de rocas
# La flor está en la cima de una pirámide: baja -> media -> ALTA -> media -> baja.
# Saltar hace ruido: salta, espera, salta. Se puede subir y bajar por ambos lados.
roca("P2_RocaBaja", "roca_baja", b + 640)
roca("P2_RocaMedia", "roca_media", b + 725)
roca("P2_RocaAlta", "roca_alta", b + 801)
roca("P2_RocaMedia2", "roca_media", b + 877)
roca("P2_RocaBaja2", "roca_baja", b + 962)
objeto("Flor", "flor", b + 801, PISO - 138 - 36)
arbusto("P2_Arbusto2", b + 1050)
chaneque("P2_Chaneque2", b + 1090, 45)           # cuida la vela
objeto("Vela", "vela", b + 1120, 510)

# ---------- Pantalla 3: el claro de cempasúchil y el arroyo ----------
c = P[2]
# Dos chaneques juntos en el claro: pasa agachada entre ellos (o distráelos),
# espera en el arbusto junto al arroyo y cruza saltando cuando estén lejos.
arbusto("P3_Arbusto1", c + 110)
chaneque("P3_Chaneque1", c + 210, 70)
chaneque("P3_Chaneque2", c + 300, 70)
arbusto("P3_Arbusto2", c + 495)
piedra("P3_Piedra1", c + 607)
piedra("P3_Piedra2", c + 685, 16.0)
piedra("P3_Piedra3", c + 763)
objeto("Petalos", "petalos", c + 685, PISO - 70)
roca("P3_RocaBaja", "roca_baja", c + 930)

escena = "[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n\n".join(sub) + "\n\n" + "\n\n".join(nodos) + "\n"
open(sys.argv[1], "w", encoding="utf-8").write(escena)
print("ok", len(nodos), "nodos")
