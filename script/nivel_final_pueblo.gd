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
## Al restaurarse el ritual, el color regresa al pueblo (amanecer cálido).
## Desactívalo si la entrega debe ser 100% en escala de grises.
@export var color_al_amanecer: bool = true
@export_multiline var creditos: String = "XANTOLO\nEl Camino de las Ánimas\n\nGuadalupe Mishel Hernández Govea\nSoraida Medina Bautista\nLuis Gustavo Hernández Hernández\n\nUniversidad Tecnológica de la Huasteca Hidalguense\nCreación de Videojuegos · 2026"

const FIG := "res://assets/pueblo/"

var _jugador: CharacterBody2D
var _oscuro: CanvasModulate
var _capa: CanvasLayer
var _negro: ColorRect
var _mensaje: Label
var _ayuda: Label
var _creditos: Label
var _fin := false
var _arco: Sprite2D
var _bailarines: Array[Sprite2D] = []
var _t := 0.0
var _murmullo: AudioStreamPlayer
var _color: ShaderMaterial
var _musicos: Array[Sprite2D] = []
var _ninos: Array[Sprite2D] = []

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

	# 1. La ofrenda: lo que Xochik recuperó + lo de la familia + el retrato
	await _decir("Xochik coloca en el altar lo que recuperó en el camino…", 2.5)
	var lista: Array[String] = []
	if Juego.ofrenda.is_empty():
		for r in ofrenda_por_defecto:
			lista.append(r)
	else:
		lista.append_array(Juego.ofrenda)
	for r in ofrenda_familia:
		lista.append(r)
	var n := lista.size()
	for i in n:
		var x := 0.0 if n == 1 else lerpf(-ancho_altar / 2.0, ancho_altar / 2.0, float(i) / (n - 1))
		_poner_objeto(lista[i], altar + Vector2(x, 12.0), 1.0 + i * 0.06)
		await get_tree().create_timer(0.6, false).timeout
	await get_tree().create_timer(0.6, false).timeout
	_poner_objeto(retrato, altar + Vector2(0, -34.0), 0.8, 1.4)
	await _decir("…y por último, su retrato.", 2.5)

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
	var destino_abuelo := (_jugador.global_position.x - 85.0) if _jugador else altar.x - 120.0
	_caminar_anima(abuelo, destino_abuelo, 0.0)
	_caminar_anima(mujer, altar.x + 95.0, 1.6)
	_caminar_anima(hombre, altar.x + 150.0, 3.2)
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
	_aparecer_familia(altar)
	_llenar_pueblo()
	await get_tree().create_timer(2.5, false).timeout
	_llega_cuadrilla()
	await _decir("El Xantolo se ha restaurado.\nVivos y muertos vuelven a estar juntos.", 6.0)
	await get_tree().create_timer(5.0, false).timeout

	_mostrar_creditos()


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


func _aparecer_familia(altar: Vector2) -> void:
	var lugares := [
		["familia_papa", altar.x - 230.0], ["familia_mama", altar.x - 170.0], ["familia_nino", altar.x - 205.0],
		["familia_tia", altar.x + 210.0],
	]
	for i in lugares.size():
		var f := _figura(lugares[i][0], Vector2(lugares[i][1], piso_y))
		f.modulate.a = 0.0
		f.flip_h = lugares[i][1] > altar.x
		var tw := create_tween()
		tw.tween_interval(i * 0.6)
		tw.tween_property(f, "modulate:a", 1.0, 1.5)
	# La abuela que guió a Xochik también está
	if ResourceLoader.exists("res://assets/abuela/abuela_idle.png"):
		var ab := Sprite2D.new()
		ab.texture = load("res://assets/abuela/abuela_idle.png")
		ab.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ab.scale = Vector2.ONE * 0.12
		ab.flip_h = true
		ab.position = Vector2(altar.x + 265.0, piso_y - (1183.0 - ab.texture.get_height() / 2.0) * 0.12)
		ab.modulate.a = 0.0
		add_child(ab)
		var tw2 := create_tween()
		tw2.tween_interval(2.4)
		tw2.tween_property(ab, "modulate:a", 1.0, 1.5)


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
		tw.parallel().tween_property(d, "position:x", arco_x + 110.0 + i * 70.0, 3.0)


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


## Llega la gente del pueblo: trío huasteco junto al arco, vecinos, niños corriendo
func _llenar_pueblo() -> void:
	# Trío huasteco recibiendo a las ánimas junto al arco
	var trio := [["musico_huapanguera", 40.0, 0.2], ["musico_violin", 100.0, 0.39], ["musico_jarana", 160.0, 0.2]]
	for i in trio.size():
		var m := _figura(trio[i][0], Vector2(trio[i][1], piso_y), 2)
		m.set_meta("paso", trio[i][2])
		m.modulate.a = 0.0
		_musicos.append(m)
		var tw := create_tween()
		tw.tween_interval(0.3 + i * 0.4)
		tw.tween_property(m, "modulate:a", 1.0, 1.2)
	# Vecinos al fondo de la plaza (más chicos y tenues: están más lejos)
	var fondo := [["senora_canasta", 470.0], ["senor_morral", 530.0], ["abuelita", 690.0],
		["joven", 1130.0], ["nina", 1165.0], ["senora_canasta", 1320.0]]
	for i in fondo.size():
		var v := _vecino(fondo[i][0], fondo[i][1])
		var tw := create_tween()
		tw.tween_interval(1.0 + i * 0.5)
		tw.tween_property(v, "modulate:a", 0.85, 1.5)
	# Gente que va llegando desde la calle de la derecha
	var llegan := [["senor_morral", 820.0], ["senora_canasta", 880.0], ["joven", 1260.0]]
	for i in llegan.size():
		var v := _vecino(llegan[i][0], 1420.0)
		v.flip_h = true
		v.modulate.a = 0.85
		var tw := create_tween()
		tw.tween_interval(2.0 + i * 1.6)
		tw.tween_property(v, "position:x", llegan[i][1], absf(1420.0 - llegan[i][1]) / 70.0)
	# Niños corriendo y jugando por la plaza
	for i in 2:
		var n := _figura("nino_corriendo", Vector2(520.0 + i * 260.0, piso_y), 2)
		n.set_meta("vel", 120.0 if i == 0 else -105.0)
		n.modulate.a = 0.0
		_ninos.append(n)
		create_tween().tween_property(n, "modulate:a", 1.0, 1.0)


func _vecino(nombre: String, x: float) -> Sprite2D:
	var v := _figura(nombre, Vector2(x, piso_y - 16.0))
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
		if n.position.x > 920.0 or n.position.x < 420.0:
			vel = -vel
			n.set_meta("vel", vel)
		n.flip_h = vel < 0.0
		n.frame = int(_t / 0.16) % 2
		n.position.y = n.get_meta("y0") - absf(sin(_t * 10.0)) * 4.0


func _iniciar_murmullo() -> void:
	var ruta := "res://assets/audio/sfx/murmullo.ogg"
	if not ResourceLoader.exists(ruta):
		return
	_murmullo = AudioStreamPlayer.new()
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
	var tw := create_tween()
	tw.tween_property(_negro, "color:a", 0.6, 2.5)   # la fiesta sigue detrás
	await tw.finished
	_creditos.text = creditos
	_creditos.modulate.a = 0.0
	_creditos.visible = true
	create_tween().tween_property(_creditos, "modulate:a", 1.0, 2.0)
	await get_tree().create_timer(3.0, false).timeout
	_ayuda.text = "[E] Volver al menú"
	_ayuda.visible = true
	_fin = true


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

	_creditos = _label(22)
	_creditos.set_anchors_preset(Control.PRESET_CENTER)
	_creditos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_creditos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_creditos.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_creditos.grow_vertical = Control.GROW_DIRECTION_BOTH
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
