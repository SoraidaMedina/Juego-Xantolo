extends Node2D
## Nivel 1 — La Sierra de los Chaneques (3 pantallas de cámara fija, como Detention)
##   1. La vereda del cañaveral: el arco de caña marca la entrada del Xantolo. Aprendes a saltar y tomas copal.
##   2. El bosque de los chaneques: la flor está en lo alto y la vela entre ellos.
##   3. El claro de cempasúchil: cruzas el arroyo de piedra en piedra; los pétalos están a la mitad.
## Agachada caminas en silencio; saltar hace ruido; en los arbustos te escondes; el copal [Q] los dispersa.
## Con la ofrenda completa, sigue la vereda a la derecha hacia el río.

@export_file("*.tscn") var siguiente_nivel: String = ""
## Ancho de cada pantalla (la cámara se queda fija en una a la vez)
@export var ancho_pantalla: int = 1152
@export var alto_pantalla: int = 648
@export var nombres_pantallas: PackedStringArray = [
	"La vereda del cañaveral",
	"El bosque de los chaneques",
	"El claro de cempasúchil",
]
## Radio (px) en el que el copal afecta a los chaneques
@export var radio_copal: float = 300.0
## Posición y tamaño del copal en la mano de Xochik
@export var offset_mano: Vector2 = Vector2(14, -6)
@export var escala_mano: float = 0.05
## Lo que dice Chicomexochitl al empezar (Xochik no se mueve mientras habla)
@export var mensajes_intro: PackedStringArray = [
	"Noche de Xantolo… el arco de caña ya está puesto, pero el ritual se rompió.",
	"La ofrenda quedó dispersa por la sierra: la vela, la flor y los pétalos.",
	"Los chaneques no ven bien… pero oyen todo. El anillo de tus pasos muestra hasta dónde te oyen.",
	"Son curiosos: lanza una piedrita  [R]  lejos y irán a ver qué fue.",
]
@export var segundos_por_mensaje: float = 3.5

const NOMBRES_FALTA := {"vela": "la vela", "flor": "la flor", "petalos": "los pétalos"}

var total := {"vela": 0, "flor": 0, "petalos": 0}
var recogidos := {"vela": 0, "flor": 0, "petalos": 0}
var copal := 0

var _hud: Label
var _lugar: Label
var _mensaje: Label
var _cortina: ColorRect
var _completado := false
var _saliendo := false
var _copal_mano: Sprite2D
var _jugador: CharacterBody2D
var _camara: Camera2D
var _pantalla := -1
var _vistas := {}
var _jugando := false        # los chaneques esperan a que termine la intro
var _tip_oido := false
var _tip_persecucion := false
var _tip_copal := false
var _tip_salto := false
var _tutorial_listo := false
var _aviso_falta := 0.0
var _espera_piedra := 0.0
const PIEDRITA := preload("res://script/piedrita.gd")


func _ready() -> void:
	add_to_group("nivel")
	_asegurar_accion("interactuar", KEY_E)
	_asegurar_accion("usar_copal", KEY_Q)
	_crear_hud()
	_jugador = get_tree().get_first_node_in_group("jugador") as CharacterBody2D
	if _jugador:
		_camara = _jugador.get_node_or_null("Camera2D") as Camera2D
		_jugador.vidas_cambiadas.connect(func(_v): _actualizar_hud())
		_jugador.sin_vidas.connect(_game_over)
	for obj in get_tree().get_nodes_in_group("recolectable"):
		obj.recogido.connect(_on_objeto_recogido)
		if total.has(obj.tipo):
			total[obj.tipo] += 1
	_actualizar_hud()
	_revisar_pantalla(true)
	_intro()


func _intro() -> void:
	if _jugador:
		_jugador.atrapada = true
	await get_tree().create_timer(0.8, false).timeout
	for m in mensajes_intro:
		await _decir(m, segundos_por_mensaje)
	if _jugador:
		_jugador.atrapada = false
	_jugando = true


func _process(delta: float) -> void:
	_espera_piedra = maxf(_espera_piedra - delta, 0.0)
	_revisar_pantalla(false)
	_revisar_tips()
	_revisar_salida(delta)
	_mover_copal_en_mano()


# ---------- Pantallas de cámara fija ----------

func pantalla_de(x: float) -> int:
	return clampi(int(floor(x / ancho_pantalla)), 0, nombres_pantallas.size() - 1)


## Los chaneques solo oyen a Xochik si están en la misma pantalla que ella
func misma_pantalla(pos: Vector2) -> bool:
	return _jugador != null and pantalla_de(pos.x) == pantalla_de(_jugador.global_position.x)


func _revisar_pantalla(inicial: bool) -> void:
	if _jugador == null:
		return
	var p := pantalla_de(_jugador.global_position.x)
	if p == _pantalla:
		return
	var de_izquierda := p > _pantalla
	_pantalla = p
	if not inicial:
		# Reaparece al entrar a esta pantalla, del lado por el que llegó
		var x := p * ancho_pantalla + (50.0 if de_izquierda else ancho_pantalla - 50.0)
		_jugador.punto_reaparicion = Vector2(x, _jugador.global_position.y - 10.0)
		_parpadeo()
	_fijar_camara(p)
	if not _vistas.has(p):
		_vistas[p] = true
		_mostrar_lugar(nombres_pantallas[p])
		if p == 1 and not inicial:
			_tutorial_chaneques()


func _fijar_camara(p: int) -> void:
	if _camara == null:
		return
	_camara.zoom = Vector2.ONE
	_camara.limit_left = p * ancho_pantalla
	_camara.limit_right = (p + 1) * ancho_pantalla
	_camara.limit_top = 0
	_camara.limit_bottom = alto_pantalla
	_camara.reset_smoothing()


## Corte breve a negro al cambiar de pantalla
func _parpadeo() -> void:
	_cortina.color.a = 0.85
	var tw := create_tween()
	tw.tween_property(_cortina, "color:a", 0.0, 0.35)


func _mostrar_lugar(nombre: String) -> void:
	_lugar.text = nombre
	_lugar.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_lugar, "modulate:a", 0.9, 0.8)
	tw.tween_interval(2.5)
	tw.tween_property(_lugar, "modulate:a", 0.0, 1.2)


# ---------- Avisos ----------

## Avisos que aparecen solo la primera vez que pasa algo
func _revisar_tips() -> void:
	if not _jugando or _completado:
		return
	for c in get_tree().get_nodes_in_group("chaneques"):
		if not _tip_oido and c.estado == "alerta":
			_tip_oido = true
			_decir("¡Te oye!  Agáchate ya  [S] … o escóndete en un arbusto", 2.5)
		elif not _tip_persecucion and c.estado == "persigue":
			_tip_persecucion = true
			Juego.susto_ambiente("chaneque")
			_decir("¡Te descubrieron! Escóndete en un arbusto o quema copal  [Q]", 3.0)
	if not _tip_salto and _pantalla == 1 and _tutorial_listo and _jugador.nivel_ruido() >= 1.6:
		_tip_salto = true
		_decir("Saltar hace ruido: salta, espera un momento y vuelve a saltar… o espera a que se esfumen", 3.5)


## La primera vez que ves a los chaneques, Chicomexochitl explica cómo pasar
func _tutorial_chaneques() -> void:
	await get_tree().create_timer(1.2, false).timeout
	await _decir("Si no te oye, no te ve.", 2.5)
	await _decir("Agáchate  [S]  y pasa junto a él: si el anillo no se marca, estás a salvo.", 4.0)
	await _decir("¿Te estorba? Lanza una piedrita  [R]  lejos y irá a ver qué fue.", 3.5)
	_tutorial_listo = true


func _decir(txt: String, seg: float) -> void:
	_mensaje.text = txt
	_mensaje.visible = true
	_mensaje.modulate.a = 0.0
	var a := create_tween()
	a.tween_property(_mensaje, "modulate:a", 1.0, 0.4)
	await get_tree().create_timer(seg, false).timeout
	if _mensaje.text != txt:
		return   # otro mensaje lo reemplazó
	var b := create_tween()
	b.tween_property(_mensaje, "modulate:a", 0.0, 0.5)
	await b.finished


# ---------- Objetos y copal ----------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("usar_copal"):
		_usar_copal()
	elif event.is_action_pressed("lanzar_piedra"):
		_lanzar_piedra()


func _lanzar_piedra() -> void:
	if _espera_piedra > 0.0 or not _jugando or _jugador == null or _jugador.atrapada:
		return
	_espera_piedra = 1.2
	var anim = _jugador.get_node_or_null("AnimatedSprite2D")
	var direccion := -1.0 if (anim != null and anim.flip_h) else 1.0
	var p := PIEDRITA.new()
	add_child(p)
	p.lanzar(_jugador.global_position + Vector2(direccion * 18.0, -40.0), direccion)


func _on_objeto_recogido(obj: ObjetoOfrenda) -> void:
	match obj.tipo:
		"vela", "flor", "petalos":
			recogidos[obj.tipo] += 1
		"copal":
			copal += 1
			_poner_copal_en_mano(obj.textura)
			if not _tip_copal:
				_tip_copal = true
				_decir("Copal: su humo aleja a los chaneques un rato  [Q].  No lo desperdicies.", 3.5)
	_actualizar_hud()
	_revisar_victoria()


func _usar_copal() -> void:
	if copal <= 0 or _completado or _jugador == null or _jugador.atrapada:
		return
	copal -= 1
	_actualizar_hud()
	Juego.sfx("copal")
	_humo_copal(_jugador.global_position + Vector2(0, -20))
	if copal == 0 and _copal_mano:
		_copal_mano.visible = false
	for c in get_tree().get_nodes_in_group("chaneques"):
		if c.global_position.distance_to(_jugador.global_position) <= radio_copal and c.has_method("dispersar"):
			c.dispersar()


func _revisar_victoria() -> void:
	if _completado:
		return
	for t in total:
		if recogidos[t] < total[t]:
			return
	_completado = true
	_decir("La ofrenda de la sierra está completa…\nSigue la vereda hacia el río  →", 4.0)


## Al llegar al final de la vereda: si la ofrenda está completa, pasa al río
func _revisar_salida(delta: float) -> void:
	_aviso_falta = maxf(_aviso_falta - delta, 0.0)
	if _jugador == null or _saliendo:
		return
	if _jugador.global_position.x < ancho_pantalla * nombres_pantallas.size() - 60.0:
		return
	if _completado:
		_saliendo = true
		_jugador.atrapada = true
		Juego.ir_a(siguiente_nivel)  # vacío = siguiente nivel de la lista
	elif _aviso_falta <= 0.0:
		_aviso_falta = 4.0
		var falta: PackedStringArray = []
		for t in total:
			if recogidos[t] < total[t]:
				falta.append(NOMBRES_FALTA[t])
		_decir("Aún falta " + ", ".join(falta) + "…", 2.5)


func _game_over() -> void:
	_completado = true
	await get_tree().create_timer(1.0, false).timeout
	Juego.game_over("Los chaneques te atraparon…")


# ---------- Copal en la mano + humo ----------

func _poner_copal_en_mano(tex: Texture2D) -> void:
	if _jugador == null:
		return
	if _copal_mano == null:
		_copal_mano = Sprite2D.new()
		_copal_mano.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_copal_mano.z_index = 1
		_jugador.add_child(_copal_mano)
	_copal_mano.texture = tex
	_copal_mano.scale = Vector2.ONE * escala_mano
	_copal_mano.visible = true


func _mover_copal_en_mano() -> void:
	if _copal_mano == null or not _copal_mano.visible:
		return
	var anim = _jugador.get_node_or_null("AnimatedSprite2D")
	var izquierda: bool = anim != null and anim.flip_h
	_copal_mano.position = Vector2(-offset_mano.x if izquierda else offset_mano.x, offset_mano.y)
	_copal_mano.flip_h = izquierda


func _humo_copal(pos: Vector2) -> void:
	var humo := CPUParticles2D.new()
	humo.global_position = pos
	humo.one_shot = true
	humo.explosiveness = 0.6
	humo.amount = 60
	humo.lifetime = 2.0
	humo.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	humo.emission_sphere_radius = 14.0
	humo.direction = Vector2.UP
	humo.spread = 80.0
	humo.initial_velocity_min = 30.0
	humo.initial_velocity_max = 100.0
	humo.gravity = Vector2(0, -25)
	humo.damping_min = 10.0
	humo.damping_max = 20.0
	humo.scale_amount_min = 4.0
	humo.scale_amount_max = 10.0
	var degradado := Gradient.new()
	degradado.set_color(0, Color(0.85, 0.85, 0.85, 0.8))
	degradado.set_color(1, Color(0.6, 0.6, 0.6, 0.0))
	humo.color_ramp = degradado
	add_child(humo)
	humo.emitting = true
	get_tree().create_timer(2.8, false).timeout.connect(humo.queue_free)


# ---------- HUD ----------

func _crear_hud() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)

	_cortina = ColorRect.new()
	_cortina.color = Color(0, 0, 0, 0)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(_cortina)

	_hud = _label_base(16)
	_hud.position = Vector2(16, 12)
	capa.add_child(_hud)

	_lugar = _label_base(22)
	_lugar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_lugar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lugar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lugar.position.y = 52
	_lugar.modulate.a = 0.0
	capa.add_child(_lugar)

	_mensaje = _label_base(20)
	_mensaje.set_anchors_preset(Control.PRESET_CENTER)
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mensaje.grow_vertical = Control.GROW_DIRECTION_BOTH
	_mensaje.modulate = Color(0.92, 0.92, 0.92)
	_mensaje.visible = false
	capa.add_child(_mensaje)


func _label_base(tam: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l


func _actualizar_hud() -> void:
	var vidas_txt := ""
	if _jugador:
		vidas_txt = "Vidas %d/%d   " % [_jugador.vidas, _jugador.vidas_max]
	_hud.text = vidas_txt + "Vela %d/%d   Flor %d/%d   Pétalos %d/%d   Copal x%d [Q]   Piedrita [R]" % [
		recogidos["vela"], total["vela"], recogidos["flor"], total["flor"],
		recogidos["petalos"], total["petalos"], copal]


func _asegurar_accion(nombre: String, tecla: Key) -> void:
	if InputMap.has_action(nombre):
		return
	InputMap.add_action(nombre)
	var ev := InputEventKey.new()
	ev.physical_keycode = tecla
	InputMap.action_add_event(nombre, ev)
