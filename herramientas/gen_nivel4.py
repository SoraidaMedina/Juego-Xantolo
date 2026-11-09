"""Genera scenes/niveles/Nivel4Cueva.tscn: la Cueva del abuelo en 2 pantallas de cámara fija.

Medidas: pantalla 1152x648, piso en y=560. Xochik salta ~62 px de alto y ~105 px de largo;
cada escalón de roca sube 46 px como máximo y los abismos miden 80 px.
Uso: python gen_nivel4.py ../scenes/niveles/Nivel4Cueva.tscn
"""
import sys

ANCHO = 1152
PISO = 560
P = [0, ANCHO]
ABISMOS = [(560, 640), (ANCHO + 700, ANCHO + 780)]   # igual que en gen_cueva.py

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


R_SCRIPT = recurso("Script", "res://scenes/niveles/nivel_4_cueva.gd")
R_F1 = recurso("Texture2D", "res://assets/cueva/cueva_1.png")
R_F2 = recurso("Texture2D", "res://assets/cueva/cueva_2.png")
R_XOCHIK = recurso("PackedScene", "res://scenes/personajes/Xochik.tscn", "uid://2mliplafc3uu")
R_CHICO = recurso("PackedScene", "res://scenes/personajes/Chicomexochitl.tscn", "uid://b8nduubajhyl7")
R_OBJ = recurso("PackedScene", "res://scenes/objeto_ofrenda.tscn")
R_TRAMPA = recurso("Script", "res://script/trampa_espiritual.gd")
R_VIENTO = recurso("Script", "res://script/corriente_aire.gd")
T = {
    "balero": recurso("Texture2D", "res://assets/cueva/balero.png"),
    "foto": recurso("Texture2D", "res://assets/objetos/retrato_familia.png"),
    "vela": recurso("Texture2D", "res://assets/objetos/vela1.png"),
    "papel_picado": recurso("Texture2D", "res://assets/objetos/papel_picado.png"),
}
for _n in ("roca_baja", "roca_media", "roca_alta"):
    T[_n] = recurso("Texture2D", f"res://assets/sierra/{_n}.png")
# Rocas sólidas: (ancho de colisión, alto donde se para Xochik, alto del sprite)
ROCA = {
    "roca_baja": (90, 46, 54),
    "roca_media": (80, 92, 100),
    "roca_alta": (72, 138, 146),
}

nodo(f'''[node name="Nivel4Cueva" type="Node2D"]
script = ExtResource("{R_SCRIPT}")''')

for i, r in enumerate([R_F1, R_F2]):
    nodo(f'''[node name="Fondo{i + 1}" type="Sprite2D" parent="."]
z_index = -10
texture_filter = 1
position = Vector2({P[i]}, 0)
texture = ExtResource("{r}")
centered = false''')

# ---------- Suelo con dos abismos ----------
nodo('[node name="Suelo" type="StaticBody2D" parent="."]')
cortes = [0] + [x for a in ABISMOS for x in a] + [ANCHO * 2]
for i in range(0, len(cortes), 2):
    a, b = cortes[i], cortes[i + 1]
    s = forma_rect(b - a, 40)
    nodo(f'''[node name="Tramo{i // 2 + 1}" type="CollisionShape2D" parent="Suelo"]
position = Vector2({(a + b) / 2}, {PISO + 20})
shape = SubResource("{s}")''')
s = forma_rect(40, 900)
nodo(f'''[node name="ParedIzq" type="CollisionShape2D" parent="Suelo"]
position = Vector2(-20, 200)
shape = SubResource("{s}")''')
nodo(f'''[node name="ParedDer" type="CollisionShape2D" parent="Suelo"]
position = Vector2({ANCHO * 2 + 20}, 200)
shape = SubResource("{s}")''')


def roca(nombre, tipo, x):
    w, alto, alto_sprite = ROCA[tipo]
    sid = forma_rect(w, alto)
    nodo(f'''[node name="{nombre}" type="StaticBody2D" parent="."]
position = Vector2({x}, {PISO})''')
    nodo(f'''[node name="Sprite2D" type="Sprite2D" parent="{nombre}"]
modulate = Color(0.8, 0.8, 0.82, 1)
texture_filter = 1
position = Vector2(0, {-alto_sprite / 2 + 2})
texture = ExtResource("{T[tipo]}")''')
    nodo(f'''[node name="CollisionShape2D" type="CollisionShape2D" parent="{nombre}"]
position = Vector2(0, {-alto / 2})
shape = SubResource("{sid}")''')


def objeto(nombre, tipo, x, y, escala):
    nodo(f'''[node name="{nombre}" parent="." instance=ExtResource("{R_OBJ}")]
position = Vector2({x}, {y})
tipo = "{tipo}"
textura = ExtResource("{T[tipo]}")
escala = {escala}
reaparece = false''')


def recuerdo(nombre, id_, x, y, escala, aviso):
    nodo(f'''[node name="{nombre}" parent="." instance=ExtResource("{R_OBJ}")]
position = Vector2({x}, {y})
tipo = "recuerdo"
textura = ExtResource("{T[id_]}")
escala = {escala}
recoger_automatico = true
reaparece = false
id_recuerdo = "{id_}"
nombre_aviso = "{aviso}"''')


def viento(nombre, cx, ancho, desfase):
    nodo(f'''[node name="{nombre}" type="Area2D" parent="."]
position = Vector2({cx}, 430)
script = ExtResource("{R_VIENTO}")
tamano = Vector2({ancho}, 260)
desfase = {desfase}''')


# ---------- Personajes ----------
nodo(f'''[node name="Xochik" parent="." instance=ExtResource("{R_XOCHIK}")]
position = Vector2(90, 480)''')
nodo(f'''[node name="Chicomexochitl" parent="." instance=ExtResource("{R_CHICO}")]
position = Vector2(170, 400)''')

# ---------- Pantalla 1: la boca de la cueva ----------
# Escalón con el papel picado, la corriente de aire sobre el primer abismo y la pirámide
# de rocas con el balero en la cima (se puede subir y bajar por ambos lados).
roca("P1_RocaBaja", "roca_baja", 250)
roca("P1_RocaMedia", "roca_media", 335)
objeto("PapelPicado", "papel_picado", 335, PISO - 92 - 34, 0.13)
viento("Viento1", 520, 440, 0.0)
roca("P1_PirBaja", "roca_baja", 760)
roca("P1_PirMedia", "roca_media", 845)
roca("P1_PirAlta", "roca_alta", 921)
roca("P1_PirMedia2", "roca_media", 997)
roca("P1_PirBaja2", "roca_baja", 1082)
recuerdo("RecuerdoBalero", "balero", 921, PISO - 138 - 38, 0.18, "El balero del abuelo")

# ---------- Pantalla 2: el corazón de la montaña ----------
c = P[1]
nodo(f'''[node name="TrampaEspiritual" type="Area2D" parent="."]
position = Vector2({c + 300}, {PISO})
script = ExtResource("{R_TRAMPA}")''')
recuerdo("RecuerdoFoto", "foto", c + 470, PISO - 46, 0.13, "La foto del abuelo")
viento("Viento2", c + 740, 460, 2.0)
recuerdo("RecuerdoVela", "vela", c + 1010, PISO - 50, 0.17, "La vela del abuelo")

escena = "[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n\n".join(sub) + "\n\n" + "\n\n".join(nodos) + "\n"
open(sys.argv[1], "w", encoding="utf-8").write(escena)
print("ok", len(nodos), "nodos")
