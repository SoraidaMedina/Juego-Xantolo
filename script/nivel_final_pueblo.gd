extends Node2D
## Escena final — El Pueblo: el Xantolo restaurado.
##  1. Xochik llega de noche a la plaza; el arco está apagado y el pueblo vacío.
##  2. Pone en el altar lo que recuperó en el camino (y al final, el retrato del abuelo).
##  3. Se forma el camino de pétalos y las ánimas entran por el arco.
##     La primera, el abuelo, se detiene junto a Xochik: el reencuentro.
##  4. Amanece: la familia aparece alrededor del altar, suenan las campanas
##     y llega una cuadrilla de disfrazados bailando el huapango completo.
##  5. Créditos sobre la fiesta.
## Necesita: Fondo, Suelo, Xochik (con Camera2D) y una Meta (meta.tscn) sobre el altar
## con "Es Entrada" DESACTIVADO.

@export_file("*.tscn") var escena_inicio: String = ""   # vacío = volver al menú principal
## Si Xochik no trae nada (por ejemplo, al probar esta escena sola), se usa esto
@export var ofrenda_por_defecto: PackedStringArray = [
	"res://assets/objetos/vela2.png",
	"res://assets/objetos/flor_cempasuchil.png",
	"res://assets/objetos/petalos.png",
	"res://assets/objetos/trompo.png",
]
## Lo que la familia ya tenía en el altar
@export var ofrenda_familia: PackedStringArray = [
	"res://assets/objetos/pan_de_muerto.png",
	"res://assets/objetos/tamales.png",
	"res://assets/objetos/naranja.png",
]
@export var retrato: String = "res://assets/objetos/retrato_familia.png"
@export var escala_objetos: float = 0.11
## Ancho del altar donde se acomodan los objetos (px)
@export var ancho_altar: float = 190.0
## Subir/bajar los objetos (solo si NO usas un Marker2D llamado "Altar")
@export var altura_objetos: float = -20.0
@export_range(0.0, 1.0) var oscuridad: float = 0.4
## Y del piso de la plaza (donde pisan los personajes)
@export var piso_y: float = 841.0
## X del arco por donde entran las ánimas y la cuadrilla
@export var arco_x: float = 250.0
## Puerta de la iglesia en el fondo (luz y gente rezando adentro)
@export var puerta_iglesia: Vector2 = Vector2(884, 616)
## Al restaurarse el ritual, el color regresa al pueblo (amanecer cálido).
## Desactívalo si la entrega debe ser 100% en escala de grises.
@export var color_al_amanecer: bool = true
## Créditos finales que suben sobre la fiesta. Cada línea: [tipo, texto].
## Tipos: titulo, sub, seccion, nombre, par ("Nombre|descripción"), texto, dedicatoria, esp, fin
@export var creditos: Array = [
	["titulo", "XANTOLO"],
	["sub", "El Camino de las Ánimas"],
	["esp", ""],
	["seccion", "Un juego de"],
	["nombre", "Guadalupe Mishel Hernández Govea"],
	["nombre", "Soraida Medina Bautista"],
	["nombre", "Luis Gustavo Hernández Hernández"],
	["esp", ""],
	["seccion", "Personajes"],
	["par", "Xochik|la niña del pueblo"],
	["par", "Chicomexochitl|el Niño del Maíz, vela viviente"],
	["par", "La abuela|la voz que guía el camino"],
	["par", "El abuelo|el ánima que vuelve a casa"],
	["par", "Los chaneques|los dueños de la sierra"],
	["par", "La Llorona|la madre que busca en el río"],
	["par", "El Nahual|el que cambia de forma en el monte"],
	["esp", ""],
	["seccion", "Música y sonido"],
	["texto", "Huapango huasteco deconstruido:\nviolín, jarana y quinta huapanguera"],
	["esp", ""],
	["seccion", "Herramientas"],
	["texto", "Godot Engine · Aseprite · Audacity · Git"],
	["esp", ""],
	["seccion", "Xantolo"],
	["texto", "La fiesta de Todos Santos en la Huasteca Hidalguense,\ncuando las ánimas vuelven a casa siguiendo\nel camino de cempasúchil y la luz de las velas."],
	["texto", "Gracias a las familias de Huejutla de Reyes\nque cada año levantan el arco y ponen la ofrenda."],
	["esp", ""],
	["seccion", "Universidad Tecnológica de la Huasteca Hidalguense"],
	["texto", "Creación de Videojuegos · 2026"],
	["esp", ""],
	["esp", ""],
	["dedicatoria", "Para nuestros abuelos,\nque cada Xantolo encuentran el camino de regreso."],
	["esp", ""],
	["esp", ""],
	["fin", "FIN"],
]
## Velocidad a la que suben los créditos (px por segundo)
@export var velocidad_creditos: float = 42.0

const FIG := "res://assets/pueblo/"

var _jugador: CharacterBody2D
var _oscuro: CanvasModulate
var _capa: CanvasLayer
var _negro: ColorRect
var _mensaje: Label
var _ayuda: Label
var _creditos: Control
var _fin := false
var _arco: Sprite2D
var _bailarines: Array[Sprite2D] = []
var _t := 0.0
var _murmullo: AudioStreamPlayer
var _color: ShaderMaterial
var _musicos: Array[Sprite2D] = []
var _ninos: Array[Sprite2D] = []
var _sahumadoras: Array[Sprite2D] = []
var _pelota: Sprite2D
var _aro_pos := Vector2.ZERO

const SHADER_COLOR := """
shader_type canvas_item;
uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D paleta : repeat_disable;
uniform float mezcla : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec3 c = texture(pantalla, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 col = texture(paleta, vec2(clamp(l, 0.0, 1.0), 0.5)).rgb;
	COLOR = vec4(mix(c, col, mezcla), 1.0);
}
"""


func _ready() -> void:
	_asegurar_accion("interactuar", KEY_E)
	_jugador = get_tree().get_first_node_in_group("jugador") as CharacterBody2D
	_configurar_camara()

	_oscuro = CanvasModulate.new()
	_oscuro.color = Color(oscuridad, oscuridad, oscuridad)
	add_child(_oscuro)
	_crear_ui()
	_crear_color()
	_crear_arco()
	_iglesia_viva()

	var meta = get_tree().get_first_node_in_group("meta")
	if meta:
		meta.alcanzada.connect(_ritual.bind(meta))

	# Llega desde la cueva: aparece desde negro
	var tw := create_tween()
	tw.tween_property(_negro, "color:a", 0.0, 2.0)
	await tw.finished
	await _decir("El pueblo… vacío. Las velas apenas encendidas.", 3.0)
	_ayuda.visible = true


func _process(delta: float) -> void:
	_t += delta
	_animar_baile()
	_animar_pueblo(delta)
	if _fin and Input.is_action_just_pressed("interactuar"):
		_fin = false
		Juego.ir_a(escena_inicio if escena_inicio != "" else Juego.MENU)


# ---------- El ritual ----------

func _ritual(meta: Node2D) -> void:
	_ayuda.visible = false
	if _jugador:
		_jugador.atrapada = true
		_jugador.velocity = Vector2.ZERO
		_jugador.get_node("AnimatedSprite2D").play("idle")
	var altar := _punto_altar(meta)
	_alejar_camara(Vector2(682, 470), 0.82, 3.0)

	# 1. Xochik camina al altar, se voltea y coloca con sus manos lo que recuperó
	await _xochik_al_altar(altar)
	var lista: Array[String] = []
	if Juego.ofrenda.is_empty():
		for r in ofrenda_por_defecto:
			lista.append(r)
	else:
		lista.append_array(Juego.ofrenda)
	var n := lista.size()
	for i in n:
		var x := 0.0 if n == 1 else lerpf(-ancho_altar / 2.0 + 30.0, ancho_altar / 2.0 - 30.0, float(i) / (n - 1))
		await _colocar(lista[i], altar + Vector2(x, 12.0), 1.0 + i * 0.06)
	await get_tree().create_timer(0.5, false).timeout
	_decir("…y por último, el retrato del abuelo.", 3.0)
	await _colocar(retrato, altar + Vector2(0, -34.0), 0.8, 1.4, 1.2)

	# 2. El altar se enciende y suenan las campanas
	var luz := _crear_luz(altar + Vector2(0, -20))
	create_tween().tween_property(luz, "energy", 1.1, 2.0)
	Juego.sfx("campanas", -4.0)
	_encender_arco()

	# 3. El camino de pétalos y las ánimas
	await _camino_de_petalos(arco_x, altar.x - 120.0)
	var abuelo := _figura("anima_abuelo", Vector2(arco_x, piso_y))
	var mujer := _figura("anima_mujer", Vector2(arco_x, piso_y))
	var hombre := _figura("anima_hombre", Vector2(arco_x, piso_y))
	for a in [abuelo, mujer, hombre]:
		a.modulate.a = 0.0
	var destino_abuelo := (_jugador.global_position.x - 85.0) if _jugador else altar.x - 200.0
	_caminar_anima(abuelo, destino_abuelo, 0.0)
	_caminar_anima(mujer, destino_abuelo - 57.0, 1.6)     # las ánimas se quedan juntas, del lado del arco
	_caminar_anima(hombre, destino_abuelo - 112.0, 3.2)
	await _decir("Las ánimas encuentran el camino de regreso a casa…", 4.0)
	await get_tree().create_timer(3.5, false).timeout

	# 4. El reencuentro: el abuelo se detiene junto a Xochik
	if _jugador:
		_jugador.get_node("AnimatedSprite2D").flip_h = true
	_pulso_de_luz((abuelo.global_position + _jugador.global_position) / 2.0 if _jugador else abuelo.global_position)
	Juego.sfx("recoger", -6.0, 0.7)
	await get_tree().create_timer(2.5, false).timeout

	# 5. Amanece: la familia, las campanas y la cuadrilla
	Juego.musica("fiesta", 2.5)
	Juego.sfx("campanas", -2.0)
	_cohetes(6)
	var amanecer := create_tween()
	amanecer.tween_property(_oscuro, "color", Color(0.93, 0.93, 0.93), 7.0)
	for a in [abuelo, mujer, hombre]:
		create_tween().tween_property(a, "modulate:a", 0.65, 7.0)
	_iniciar_murmullo()
	if _color:
		create_tween().tween_property(_color, "shader_parameter/mezcla", 1.0, 8.0)
	_familia_llega(altar)
	_llenar_pueblo()
	await get_tree().create_timer(2.5, false).timeout
	_llega_cuadrilla()
	await _decir("El Xantolo se ha restaurado.\nVivos y muertos vuelven a estar juntos.", 6.0)
	await get_tree().create_timer(5.0, false).timeout

	_mostrar_creditos()


## Xochik camina hasta quedar frente al altar y se voltea hacia él
func _xochik_al_altar(altar: Vector2) -> void:
	if _jugador == null:
		return
	var anim: AnimatedSprite2D = _jugador.get_node("AnimatedSprite2D")
	var destino := altar.x - 120.0
	var dx := destino - _jugador.global_position.x
	if absf(dx) > 4.0:
		anim.flip_h = dx < 0.0
		anim.play("walk")
		var tw := create_tween()
		tw.tween_property(_jugador, "global_position:x", destino, absf(dx) / 110.0)
		await tw.finished
	anim.flip_h = false          # mira hacia el altar
	anim.play("idle")
	await get_tree().create_timer(0.4, false).timeout


## Xochik toma el objeto, se inclina y lo deja en su lugar (no aparece por arte de magia)
func _colocar(ruta: String, destino: Vector2, tono: float, escala_extra: float = 1.0, pausa: float = 0.35) -> void:
	if not ResourceLoader.exists(ruta):
		return
	var tex: Texture2D = load(ruta)
	var desde := destino + Vector2(-90, -40)
	if _jugador:
		_jugador.mostrar_en_mano(tex)
		var mano = _jugador.get("_mano")
		if mano:
			desde = mano.global_position
	await get_tree().create_timer(pausa, false).timeout
	var anim: AnimatedSprite2D = _jugador.get_node("AnimatedSprite2D") if _jugador else null
	if anim:   # se inclina hacia la mesa
		create_tween().tween_property(anim, "rotation", 0.12, 0.2)
	if _jugador:
		_jugador.ocultar_mano()
	await _llevar_a_mesa(tex, desde, destino, escala_extra)
	if anim:
		create_tween().tween_property(anim, "rotation", 0.0, 0.25)
	_vela_en(destino, tono)
	await get_tree().create_timer(0.25, false).timeout


## Mueve un objeto en un arco suave desde una mano hasta su lugar en la mesa
func _llevar_a_mesa(tex: Texture2D, desde: Vector2, hasta: Vector2, escala_extra: float = 1.0) -> void:
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * escala_objetos * escala_extra
	s.global_position = desde
	add_child(s)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(_mover_en_arco.bind(s, desde, hasta, 28.0), 0.0, 1.0, 0.55)
	await tw.finished


## Posición en un arco (t de 0 a 1): sirve para lanzar objetos a la mesa y la pelota
func _mover_en_arco(t: float, nodo: Node2D, desde: Vector2, hasta: Vector2, altura: float) -> void:
	if is_instance_valid(nodo):
		nodo.global_position = desde.lerp(hasta, t) + Vector2(0, -sin(t * PI) * altura)


func _vela_en(pos: Vector2, tono: float) -> void:
	var vela := _crear_luz(pos + Vector2(0, -6))
	vela.texture_scale = 0.35
	create_tween().tween_property(vela, "energy", 0.7, 0.6)
	Juego.sfx("vela", -6.0, tono)


## Si existe un Marker2D llamado "Altar", los objetos se acomodan ahí (centro de la mesa)
func _punto_altar(meta: Node2D) -> Vector2:
	var m := get_node_or_null("Altar") as Node2D
	if m:
		return m.global_position
	return meta.global_position + Vector2(0, altura_objetos)


func _poner_objeto(ruta: String, pos: Vector2, tono: float, escala_extra: float = 1.0) -> void:
	if not ResourceLoader.exists(ruta):
		return
	var s := Sprite2D.new()
	s.texture = load(ruta)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * escala_objetos * escala_extra
	s.global_position = pos + Vector2(0, 12)
	s.modulate.a = 0.0
	add_child(s)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(s, "modulate:a", 1.0, 0.5)
	tw.tween_property(s, "global_position:y", pos.y, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Cada objeto enciende una veladora
	var vela := _crear_luz(pos + Vector2(0, -6))
	vela.texture_scale = 0.35
	create_tween().tween_property(vela, "energy", 0.7, 0.6)
	Juego.sfx("vela", -6.0, tono)


# ---------- Arco y camino de pétalos ----------

func _crear_arco() -> void:
	_arco = Sprite2D.new()
	_arco.texture = load("res://assets/sierra/arco_xantolo.png")
	_arco.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_arco.position = Vector2(arco_x, piso_y - _arco.texture.get_height() / 2.0 + 4.0)
	_arco.z_index = -1
	_arco.modulate = Color(0.55, 0.55, 0.55)
	add_child(_arco)


func _encender_arco() -> void:
	create_tween().tween_property(_arco, "modulate", Color(1.15, 1.15, 1.15), 2.0)
	var luz := _crear_luz(_arco.position + Vector2(0, -60))
	luz.texture_scale = 1.4
	create_tween().tween_property(luz, "energy", 0.6, 2.0)


func _camino_de_petalos(desde: float, hasta: float) -> void:
	var camino := _Camino.new()
	camino.y = piso_y + 4.0
	add_child(camino)
	var x := desde
	while x < hasta:
		camino.agregar(x + randf_range(-3, 3))
		x += 9.0
		if int(x) % 45 < 9:
			await get_tree().create_timer(0.04, false).timeout


class _Camino extends Node2D:
	var y := 0.0
	var _puntos: Array[Vector2] = []
	var _nacido: Array[float] = []
	var _t := 0.0

	func agregar(x: float) -> void:
		for k in 3:
			_puntos.append(Vector2(x + randf_range(-4, 4), y + randf_range(-5, 5)))
			_nacido.append(_t)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for i in _puntos.size():
			var a := clampf((_t - _nacido[i]) / 0.4, 0.0, 1.0)
			var brillo := 0.75 + 0.15 * sin(_t * 3.0 + i)
			draw_circle(_puntos[i], 2.6, Color(brillo, brillo, brillo, a))
			draw_circle(_puntos[i], 6.0, Color(1, 1, 1, a * 0.08))


# ---------- Personajes ----------

func _figura(nombre: String, pie: Vector2, cuadros: int = 1) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(FIG + nombre + ".png")
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.hframes = cuadros
	var alto := s.texture.get_height()
	s.position = pie - Vector2(0, alto / 2.0)
	s.set_meta("y0", s.position.y)
	add_child(s)
	return s


func _caminar_anima(a: Sprite2D, destino_x: float, retraso: float) -> void:
	await get_tree().create_timer(retraso, false).timeout
	create_tween().tween_property(a, "modulate:a", 0.9, 1.2)
	a.flip_h = destino_x < a.position.x
	var dur := absf(destino_x - a.position.x) / 85.0
	var tw := create_tween()
	tw.tween_property(a, "position:x", destino_x, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Flota: sube y baja mientras camina
	var flota := create_tween().set_loops()
	flota.tween_property(a, "position:y", a.get_meta("y0") - 5.0, 1.1).set_trans(Tween.TRANS_SINE)
	flota.tween_property(a, "position:y", a.get_meta("y0"), 1.1).set_trans(Tween.TRANS_SINE)


func _pulso_de_luz(pos: Vector2) -> void:
	var l := _crear_luz(pos + Vector2(0, -60))
	l.texture_scale = 0.4
	var tw := create_tween()
	tw.tween_property(l, "energy", 1.6, 0.6)
	tw.parallel().tween_property(l, "texture_scale", 1.6, 1.4)
	tw.tween_property(l, "energy", 0.35, 1.5)


## Al amanecer la familia llega por la calle con lo que trae para la ofrenda,
## lo deja en el altar y se queda del lado derecho (los vivos), frente a las ánimas.
func _familia_llega(altar: Vector2) -> void:
	var llegan := [
		["familia_mama", altar.x + 110.0, 0, Vector2(-50, -6)],
		["familia_nino", altar.x + 150.0, -1, Vector2.ZERO],
		["familia_papa", altar.x + 195.0, 1, Vector2(0, -6)],
		["familia_tia", altar.x + 245.0, 2, Vector2(50, -6)],
	]
	for i in llegan.size():
		var datos: Array = llegan[i]
		var f := _figura(datos[0], Vector2(1430.0 + i * 40.0, piso_y))
		f.flip_h = true
		_familiar_camina(f, altar, datos[1], datos[2], datos[3], i * 1.4)
	# La abuela que guió a Xochik también está
	if ResourceLoader.exists("res://assets/abuela/abuela_idle.png"):
		var ab := Sprite2D.new()
		ab.texture = load("res://assets/abuela/abuela_idle.png")
		ab.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ab.scale = Vector2.ONE * 0.12
		ab.flip_h = true
		ab.position = Vector2(altar.x + 300.0, piso_y - (1183.0 - ab.texture.get_height() / 2.0) * 0.12)
		ab.modulate.a = 0.0
		add_child(ab)
		var tw2 := create_tween()
		tw2.tween_interval(6.0)
		tw2.tween_property(ab, "modulate:a", 1.0, 1.5)


func _familiar_camina(f: Sprite2D, altar: Vector2, lugar_x: float, i_objeto: int, hueco: Vector2, retraso: float) -> void:
	await get_tree().create_timer(retraso, false).timeout
	var y0: float = f.get_meta("y0")
	var paso := create_tween().set_loops()
	paso.tween_property(f, "position:y", y0 - 3.0, 0.22)
	paso.tween_property(f, "position:y", y0, 0.22)
	if i_objeto >= 0 and i_objeto < ofrenda_familia.size():
		# Camina hasta la mesa con lo que trae, lo deja y se retira a su lugar
		var tw := create_tween()
		tw.tween_property(f, "position:x", altar.x + 70.0 + hueco.x * 0.3, absf(f.position.x - altar.x) / 80.0)
		await tw.finished
		paso.pause()
		f.position.y = y0
		var tex: Texture2D = load(ofrenda_familia[i_objeto])
		await _llevar_a_mesa(tex, f.position + Vector2(-20, -20), altar + hueco)
		_vela_en(altar + hueco, 1.1)
		await get_tree().create_timer(0.4, false).timeout
		paso.play()
	var tw2 := create_tween()
	tw2.tween_property(f, "position:x", lugar_x, absf(f.position.x - lugar_x) / 80.0 + 0.1)
	await tw2.finished
	paso.kill()
	f.position.y = y0


func _llega_cuadrilla() -> void:
	var tipos := ["disfrazado_huehue", "disfrazado_diablo", "disfrazado_mujer", "disfrazado_muerte", "disfrazado_huehue"]
	for i in tipos.size():
		var d := _figura(tipos[i], Vector2(arco_x, piso_y), 2)
		d.modulate.a = 0.0
		d.set_meta("fase", i * 0.5)
		_bailarines.append(d)
		var tw := create_tween()
		tw.tween_interval(i * 0.9)
		tw.tween_property(d, "modulate:a", 1.0, 0.5)
		tw.parallel().tween_property(d, "position:x", arco_x + 190.0 + i * 62.0, 3.0)


## Zapateado: alterna los 2 cuadros con el ritmo del huapango y rebota
func _animar_baile() -> void:
	var paso := 0.39   # segundos por paso (una corchea y media a 116 bpm)
	for d in _bailarines:
		var f: float = _t / paso + d.get_meta("fase")
		d.frame = int(f) % 2
		d.position.y = d.get_meta("y0") - absf(sin(f * PI)) * 6.0
		d.flip_h = int(f / 8.0) % 2 == 1   # cada tanto se voltean, como en la danza


## Cohetes de fiesta: en Huejutla se recibe a las ánimas con campanas y cohetes
func _cohetes(cuantos: int) -> void:
	for i in cuantos:
		await get_tree().create_timer(randf_range(1.6, 3.2), false).timeout
		Juego.sfx("cohete", -9.0, randf_range(0.9, 1.1))
		await get_tree().create_timer(0.9, false).timeout
		var p := CPUParticles2D.new()
		p.position = Vector2(randf_range(150.0, 1250.0), randf_range(130.0, 280.0))
		p.one_shot = true
		p.explosiveness = 1.0
		p.amount = 70
		p.lifetime = 1.6
		p.direction = Vector2.UP
		p.spread = 180.0
		p.initial_velocity_min = 90.0
		p.initial_velocity_max = 170.0
		p.gravity = Vector2(0, 70)
		p.damping_min = 30.0
		p.damping_max = 50.0
		p.scale_amount_min = 1.5
		p.scale_amount_max = 3.0
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(0.6, 0.6, 0.6, 0))
		p.color_ramp = g
		add_child(p)
		p.emitting = true
		get_tree().create_timer(2.5, false).timeout.connect(p.queue_free)


# ---------- El pueblo cobra vida ----------

## Capa que pinta la escena con los colores del amanecer (mapa de degradado por brillo)
func _crear_color() -> void:
	if not color_al_amanecer:
		return
	var capa := CanvasLayer.new()
	capa.layer = 1
	add_child(capa)
	_capa.layer = 2   # los textos quedan encima, en blanco
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.55, 0.8, 1.0])
	g.colors = PackedColorArray([
		Color(0.07, 0.06, 0.14),   # sombras: añil
		Color(0.36, 0.2, 0.26),    # medios oscuros: adobe rosado
		Color(0.8, 0.45, 0.2),     # medios: cempasúchil
		Color(1.0, 0.76, 0.42),    # luces: dorado
		Color(1.0, 0.96, 0.86),    # brillos
	])
	var tex := GradientTexture1D.new()
	tex.gradient = g
	var sh := Shader.new()
	sh.code = SHADER_COLOR
	_color = ShaderMaterial.new()
	_color.shader = sh
	_color.set_shader_parameter("paleta", tex)
	_color.set_shader_parameter("mezcla", 0.0)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = _color
	capa.add_child(r)


## Llega la gente del pueblo: sahumadoras en el arco, trío junto a la iglesia,
## niños jugando en la cancha, vecinos que llegan por la calle
func _llenar_pueblo() -> void:
	# Dos señoras sahumando el arco con copal
	for datos in [[arco_x - 112.0, false], [arco_x + 112.0, true]]:
		var sa := _figura("sahumadora", Vector2(datos[0], piso_y), 2)
		sa.flip_h = datos[1]
		sa.modulate.a = 0.0
		sa.set_meta("humo", _crear_humo(sa))
		_sahumadoras.append(sa)
		create_tween().tween_property(sa, "modulate:a", 1.0, 1.5)
	# Trío huasteco tocando frente a la iglesia
	var trio := [["musico_huapanguera", 560.0, 0.2], ["musico_violin", 615.0, 0.39], ["musico_jarana", 670.0, 0.2]]
	for i in trio.size():
		var m := _vecino(trio[i][0], trio[i][1], 2)
		m.set_meta("paso", trio[i][2])
		_musicos.append(m)
		var tw := create_tween()
		tw.tween_interval(0.3 + i * 0.4)
		tw.tween_property(m, "modulate:a", 0.9, 1.2)
	# La cancha: un aro y niños pasándose la pelota
	var aro := _vecino("aro_basquet", 40.0)
	aro.flip_h = false
	create_tween().tween_property(aro, "modulate:a", 0.9, 1.0)
	_aro_pos = aro.position + Vector2(10.0, -aro.texture.get_height() * 0.86 / 2.0 + 28.0)
	for i in 2:
		var nino := _vecino("nino_corriendo" if i == 0 else "nina", 150.0 + i * 120.0, 2 if i == 0 else 1)
		nino.set_meta("vel", 70.0 if i == 0 else -55.0)
		_ninos.append(nino)
		create_tween().tween_property(nino, "modulate:a", 0.9, 1.0)
	_pelota = Sprite2D.new()
	_pelota.texture = load(FIG + "pelota.png")
	_pelota.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pelota.z_index = -1
	_pelota.position = _ninos[0].position + Vector2(0, -20)
	add_child(_pelota)
	_jugar_pelota()
	# Vecinos al fondo de la plaza y gente que va llegando por la calle
	for datos in [["senora_canasta", 470.0], ["senor_morral", 755.0], ["joven", 1250.0]]:
		var v := _vecino(datos[0], datos[1])
		create_tween().tween_property(v, "modulate:a", 0.85, 1.5)
	var llegan := [["senor_morral", 1300.0], ["senora_canasta", 1340.0], ["abuelita", 720.0]]
	for i in llegan.size():
		var v := _vecino(llegan[i][0], 1430.0)
		v.flip_h = true
		v.modulate.a = 0.85
		var tw := create_tween()
		tw.tween_interval(3.0 + i * 1.8)
		tw.tween_property(v, "position:x", llegan[i][1], absf(1430.0 - llegan[i][1]) / 70.0)


## La iglesia está abierta toda la noche: luz en la puerta y gente rezando adentro
func _iglesia_viva() -> void:
	var puerta := _crear_luz(puerta_iglesia + Vector2(0, -20))
	puerta.texture_scale = 0.45
	puerta.energy = 0.8
	for y in [425.0, 480.0]:   # ventanas del campanario
		var v := _crear_luz(Vector2(puerta_iglesia.x - 4.0, y))
		v.texture_scale = 0.18
		v.energy = 0.5
	var adentro := ["abuelita", "familia_mama", "senor_morral", "nina"]
	for i in adentro.size():
		var g := Sprite2D.new()
		g.texture = load(FIG + adentro[i] + ".png")
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		g.scale = Vector2.ONE * 0.3
		g.flip_h = i % 2 == 0
		g.z_index = -5
		g.modulate = Color(0.12, 0.12, 0.12, 0.95)
		g.position = Vector2(puerta_iglesia.x - 11.0 + i * 7.5, puerta_iglesia.y + 36.0 - g.texture.get_height() * 0.15)
		add_child(g)


func _crear_humo(sa: Sprite2D) -> CPUParticles2D:
	var h := CPUParticles2D.new()
	h.amount = 24
	h.lifetime = 2.6
	h.direction = Vector2.UP
	h.spread = 20.0
	h.initial_velocity_min = 18.0
	h.initial_velocity_max = 34.0
	h.gravity = Vector2(6, -4)
	h.scale_amount_min = 3.0
	h.scale_amount_max = 8.0
	var g := Gradient.new()
	g.set_color(0, Color(0.95, 0.95, 0.95, 0.55))
	g.set_color(1, Color(0.8, 0.8, 0.8, 0.0))
	h.color_ramp = g
	sa.add_child(h)
	return h


## Los niños se pasan la pelota y de vez en cuando tiran al aro
func _jugar_pelota() -> void:
	var turno := 0
	while is_inside_tree():
		await get_tree().create_timer(1.1, false).timeout
		var desde := _pelota.position
		var hasta: Vector2
		if turno % 4 == 3:
			hasta = _aro_pos
		else:
			hasta = _ninos[turno % 2].position + Vector2(0, -24)
		turno += 1
		var tw := create_tween()
		tw.tween_method(_mover_en_arco.bind(_pelota, desde, hasta, 60.0), 0.0, 1.0, 0.7)
		await tw.finished


func _vecino(nombre: String, x: float, cuadros: int = 1) -> Sprite2D:
	var v := _figura(nombre, Vector2(x, piso_y - 16.0), cuadros)
	v.scale = Vector2.ONE * 0.86
	v.position.y += v.texture.get_height() * 0.07
	v.set_meta("y0", v.position.y)
	v.z_index = -1
	v.modulate = Color(0.85, 0.85, 0.85, 0.0)
	return v


func _animar_pueblo(delta: float) -> void:
	for m in _musicos:
		m.frame = int(_t / float(m.get_meta("paso"))) % 2
	for n in _ninos:
		var vel: float = n.get_meta("vel")
		n.position.x += vel * delta
		if n.position.x > 330.0 or n.position.x < 110.0:
			vel = -vel
			n.set_meta("vel", vel)
		n.flip_h = vel < 0.0
		if n.hframes > 1:
			n.frame = int(_t / 0.18) % 2
		n.position.y = n.get_meta("y0") - absf(sin(_t * 8.0)) * 3.0
	for sa in _sahumadoras:
		# El sahumerio se mece; el humo sale de la brasa
		sa.frame = int(_t / 0.6) % 2
		var bx := 26.0 if sa.frame == 0 else 14.0
		var humo: CPUParticles2D = sa.get_meta("humo")
		humo.position = Vector2(-bx if sa.flip_h else bx, 18.0)


func _iniciar_murmullo() -> void:
	var ruta := "res://assets/audio/sfx/murmullo.ogg"
	if not ResourceLoader.exists(ruta):
		return
	_murmullo = AudioStreamPlayer.new()
	_murmullo.bus = "Efectos"
	var st = load(ruta)
	if st is AudioStreamOggVorbis:
		st.loop = true
	_murmullo.stream = st
	_murmullo.volume_db = -40.0
	add_child(_murmullo)
	_murmullo.play()
	create_tween().tween_property(_murmullo, "volume_db", -14.0, 4.0)


func _crear_luz(pos: Vector2) -> PointLight2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var l := PointLight2D.new()
	l.texture = tex
	l.texture_scale = 2.0
	l.color = Color(1, 1, 1)
	l.energy = 0.0
	l.global_position = pos
	add_child(l)
	return l


func _mostrar_creditos() -> void:
	Juego.borrar_partida()   # el juego terminó: el menú ya no ofrece "Continuar"
	var tw := create_tween()
	tw.tween_property(_negro, "color:a", 0.62, 2.5)   # la fiesta sigue detrás
	await tw.finished
	var rollo := VBoxContainer.new()
	rollo.add_theme_constant_override("separation", 8)
	rollo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fin: Control = null
	for linea in creditos:
		var n := _linea_credito(String(linea[0]), String(linea[1]))
		rollo.add_child(n)
		if String(linea[0]) == "fin":
			fin = n
	_creditos.add_child(rollo)
	_creditos.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	var pantalla := get_viewport().get_visible_rect().size
	rollo.size.x = pantalla.x
	rollo.position = Vector2(0, pantalla.y + 20)
	# Sube hasta que "FIN" quede en el centro de la pantalla
	var centro_fin: float = rollo.size.y
	if fin:
		centro_fin = fin.position.y + fin.size.y * 0.5
	var destino: float = pantalla.y * 0.5 - centro_fin
	var dur: float = (rollo.position.y - destino) / maxf(velocidad_creditos, 1.0)
	var sube := create_tween()
	sube.tween_property(rollo, "position:y", destino, dur)
	await get_tree().create_timer(6.0, false).timeout
	_ayuda.text = "[E] Volver al menú"
	_ayuda.visible = true
	_fin = true


func _linea_credito(tipo: String, texto: String) -> Control:
	if tipo == "esp":
		var c := Control.new()
		c.custom_minimum_size = Vector2(0, 26)
		return c
	if tipo == "par":
		var partes := texto.split("|")
		var fila := HBoxContainer.new()
		fila.alignment = BoxContainer.ALIGNMENT_CENTER
		fila.add_theme_constant_override("separation", 16)
		var quien := _label(19)
		quien.text = partes[0]
		quien.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		quien.custom_minimum_size = Vector2(260, 0)
		quien.add_theme_color_override("font_color", Color.WHITE)
		var que := _label(17)
		que.text = partes[1] if partes.size() > 1 else ""
		que.custom_minimum_size = Vector2(360, 0)
		que.modulate = Color(0.78, 0.78, 0.78)
		fila.add_child(quien)
		fila.add_child(que)
		return fila
	var tam := {"titulo": 54, "sub": 22, "seccion": 15, "nombre": 22, "texto": 17, "dedicatoria": 22, "fin": 44}
	var l := _label(int(tam.get(tipo, 18)))
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match tipo:
		"titulo", "fin":
			l.add_theme_constant_override("outline_size", 8)
		"seccion":
			l.text = " ".join(texto.to_upper().split(""))
			l.modulate = Color(0.62, 0.62, 0.62)
		"texto":
			l.modulate = Color(0.85, 0.85, 0.85)
		"dedicatoria":
			l.modulate = Color(1.0, 0.92, 0.78)
	return l


# ---------- Cámara ----------

func _configurar_camara() -> void:
	if _jugador == null:
		return
	var camara := _jugador.get_node_or_null("Camera2D") as Camera2D
	if camara == null:
		return
	var fondo := get_node_or_null("Fondo") as Sprite2D
	if fondo and fondo.texture:
		var r := fondo.get_rect()
		var e1 := fondo.to_global(r.position)
		var e2 := fondo.to_global(r.end)
		camara.limit_left = int(minf(e1.x, e2.x))
		camara.limit_top = int(minf(e1.y, e2.y))
		camara.limit_right = int(maxf(e1.x, e2.x))
		camara.limit_bottom = int(maxf(e1.y, e2.y))


## Pasa a una cámara fija que se aleja para ver toda la plaza
func _alejar_camara(centro: Vector2, zoom: float, dur: float) -> void:
	var actual := get_viewport().get_camera_2d()
	var cam := Camera2D.new()
	add_child(cam)
	cam.global_position = actual.get_screen_center_position() if actual else centro
	cam.zoom = actual.zoom if actual else Vector2.ONE
	cam.make_current()
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "global_position", centro, dur)
	tw.tween_property(cam, "zoom", Vector2.ONE * zoom, dur)


# ---------- UI ----------

func _crear_ui() -> void:
	_capa = CanvasLayer.new()
	add_child(_capa)

	_negro = ColorRect.new()
	_negro.color = Color(0, 0, 0, 1)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capa.add_child(_negro)

	_mensaje = _label(20)
	_mensaje.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mensaje.position.y = 60
	_mensaje.modulate = Color(0.95, 0.95, 0.95)
	_mensaje.visible = false
	_capa.add_child(_mensaje)

	_creditos = Control.new()
	_creditos.set_anchors_preset(Control.PRESET_FULL_RECT)
	_creditos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_creditos.clip_contents = true
	_creditos.visible = false
	_capa.add_child(_creditos)

	_ayuda = _label(14)
	_ayuda.text = "Lleva la ofrenda al altar →"
	_ayuda.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ayuda.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ayuda.position.y = get_viewport().get_visible_rect().size.y - 40
	_ayuda.modulate = Color(1, 1, 1, 0.8)
	_ayuda.visible = false
	_capa.add_child(_ayuda)


func _label(tam: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l


func _decir(txt: String, seg: float) -> void:
	_mensaje.text = txt
	_mensaje.modulate.a = 0.0
	_mensaje.visible = true
	var a := create_tween()
	a.tween_property(_mensaje, "modulate:a", 1.0, 0.6)
	await get_tree().create_timer(seg, false).timeout
	if _mensaje.text != txt:
		return
	var b := create_tween()
	b.tween_property(_mensaje, "modulate:a", 0.0, 0.6)
	await b.finished


func _asegurar_accion(nombre: String, tecla: Key) -> void:
	if InputMap.has_action(nombre):
		return
	InputMap.add_action(nombre)
	var ev := InputEventKey.new()
	ev.physical_keycode = tecla
	InputMap.action_add_event(nombre, ev)
