extends Node2D
## Nivel 1 — La Sierra de los Chaneques
## Objetivo: recuperar la vela, la flor y los pétalos de la ofrenda sin que los chaneques te oigan.
## Agachada caminas en silencio; en los arbustos te escondes; el copal [Q] los dispersa.

@export var ancho_nivel: int = 1152
@export var alto_nivel: int = 648
@export_file("*.tscn") var siguiente_nivel: String = ""
## Segundos que tarda el copal en volver a su lugar después de usarlo
@export var tiempo_reaparece_copal: float = 2.0
## Radio (px) en el que el copal afecta a los chaneques
@export var radio_copal: float = 260.0
## Posición del copal en la mano de Xochik (relativa a ella, mirando a la derecha)
@export var offset_mano: Vector2 = Vector2(14, -6)
## Tamaño del copal en la mano
@export var escala_mano: float = 0.05
## Lo que dice Chicomexochitl al empezar (Xochik no se mueve mientras habla)
@export var mensajes_intro: PackedStringArray = [
	"Noche de Xantolo… el ritual se rompió y la ofrenda quedó dispersa por la sierra.",
	"Recupera la vela, la flor de cempasúchil y los pétalos  [E]",
	"Los chaneques oyen tus pasos. Agáchate  [S]  para caminar en silencio.",
]
@export var segundos_por_mensaje: float = 3.5

var total := {"vela": 0, "flor": 0, "petalos": 0}
var recogidos := {"vela": 0, "flor": 0, "petalos": 0}
var copal := 0

var _hud: Label
var _mensaje: Label
var _completado := false
var _copal_mano: Sprite2D
var _copales_usables: Array = []
var _jugador: Node
var _jugando := false        # los chaneques esperan a que termine la intro
var _tip_oido := false
var _tip_persecucion := false
var _tip_copal := false


func _ready() -> void:
	add_to_group("nivel")
	_asegurar_accion("interactuar", KEY_E)
	_asegurar_accion("usar_copal", KEY_Q)
	_configurar_camara()
	_crear_hud()
	_jugador = get_tree().get_first_node_in_group("jugador")
	if _jugador:
		_jugador.vidas_cambiadas.connect(func(_v): _actualizar_hud())
		_jugador.sin_vidas.connect(_game_over)
	for obj in get_tree().get_nodes_in_group("recolectable"):
		obj.recogido.connect(_on_objeto_recogido)
		if total.has(obj.tipo):
			total[obj.tipo] += 1
	_actualizar_hud()
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


## Avisos que aparecen solo la primera vez que pasa algo
func _revisar_tips() -> void:
	if not _jugando or _completado:
		return
	for c in get_tree().get_nodes_in_group("chaneques"):
		if not _tip_oido and c.estado == "alerta":
			_tip_oido = true
			_decir("Te escuchan… agáchate y quédate quieta", 2.5)
		elif not _tip_persecucion and c.estado == "persigue":
			_tip_persecucion = true
			_decir("¡Te descubrieron! Escóndete en un arbusto o quema copal  [Q]", 3.0)
	if not _tip_copal and copal > 0:
		_tip_copal = true
		_decir("Copal: su humo aleja a los chaneques un rato  [Q]", 3.0)


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


func _configurar_camara() -> void:
	var jugador = get_tree().get_first_node_in_group("jugador")
	if jugador == null:
		return
	var camara := jugador.get_node_or_null("Camera2D") as Camera2D
	if camara == null:
		return
	camara.zoom = Vector2.ONE
	# Si hay un Sprite2D llamado "Fondo", los límites salen de su tamaño real
	var fondo := get_node_or_null("Fondo") as Sprite2D
	if fondo and fondo.texture:
		var r := fondo.get_rect()
		var esq1 := fondo.to_global(r.position)
		var esq2 := fondo.to_global(r.end)
		camara.limit_left = int(minf(esq1.x, esq2.x))
		camara.limit_top = int(minf(esq1.y, esq2.y))
		camara.limit_right = int(maxf(esq1.x, esq2.x))
		camara.limit_bottom = int(maxf(esq1.y, esq2.y))
	else:
		camara.limit_left = 0
		camara.limit_top = 0
		camara.limit_right = ancho_nivel
		camara.limit_bottom = alto_nivel


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("usar_copal"):
		_usar_copal()


func _on_objeto_recogido(obj: ObjetoOfrenda) -> void:
	match obj.tipo:
		"vela", "flor", "petalos":
			recogidos[obj.tipo] += 1
		"copal":
			copal += 1
			_poner_copal_en_mano(obj.textura)
			if obj.reaparece:
				_copales_usables.append(obj)
	_actualizar_hud()
	_revisar_victoria()


func _usar_copal() -> void:
	if copal <= 0 or _completado:
		return
	copal -= 1
	_actualizar_hud()
	var jugador = get_tree().get_first_node_in_group("jugador")
	if jugador == null:
		return
	_humo_copal(jugador.global_position + Vector2(0, -20))
	if copal == 0 and _copal_mano:
		_copal_mano.visible = false
	if not _copales_usables.is_empty():
		var obj = _copales_usables.pop_front()
		get_tree().create_timer(tiempo_reaparece_copal, false).timeout.connect(obj.reaparecer)
	for c in get_tree().get_nodes_in_group("chaneques"):
		if c.global_position.distance_to(jugador.global_position) <= radio_copal and c.has_method("dispersar"):
			c.dispersar()


func _revisar_victoria() -> void:
	if _completado:
		return
	for t in total:
		if recogidos[t] < total[t]:
			return
	_completado = true
	_decir("La ofrenda de la sierra está completa…\nChicomexochitl ilumina el camino hacia el río", 3.5)
	await get_tree().create_timer(3.0, false).timeout
	Juego.ir_a(siguiente_nivel)  # vacío = siguiente nivel de la lista


func _game_over() -> void:
	_completado = true
	await get_tree().create_timer(1.0, false).timeout
	Juego.game_over("Los chaneques te atraparon…")


# ---------- Copal en la mano + humo ----------

func _poner_copal_en_mano(tex: Texture2D) -> void:
	var jugador = get_tree().get_first_node_in_group("jugador")
	if jugador == null:
		return
	if _copal_mano == null:
		_copal_mano = Sprite2D.new()
		_copal_mano.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_copal_mano.z_index = 1
		jugador.add_child(_copal_mano)
	_copal_mano.texture = tex
	_copal_mano.scale = Vector2.ONE * escala_mano
	_copal_mano.visible = true


func _process(_delta: float) -> void:
	_revisar_tips()
	# El copal sigue la mano y se voltea con Xochik
	if _copal_mano == null or not _copal_mano.visible:
		return
	var anim = _copal_mano.get_parent().get_node_or_null("AnimatedSprite2D")
	var izquierda: bool = anim != null and anim.flip_h
	_copal_mano.position = Vector2(-offset_mano.x if izquierda else offset_mano.x, offset_mano.y)
	_copal_mano.flip_h = izquierda


func _humo_copal(pos: Vector2) -> void:
	var humo := CPUParticles2D.new()
	humo.global_position = pos
	humo.one_shot = true
	humo.explosiveness = 0.6
	humo.amount = 50
	humo.lifetime = 1.8
	humo.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	humo.emission_sphere_radius = 12.0
	humo.direction = Vector2.UP
	humo.spread = 70.0
	humo.initial_velocity_min = 30.0
	humo.initial_velocity_max = 90.0
	humo.gravity = Vector2(0, -25)
	humo.damping_min = 10.0
	humo.damping_max = 20.0
	humo.scale_amount_min = 4.0
	humo.scale_amount_max = 9.0
	var degradado := Gradient.new()
	degradado.set_color(0, Color(0.85, 0.85, 0.85, 0.8))
	degradado.set_color(1, Color(0.6, 0.6, 0.6, 0.0))
	humo.color_ramp = degradado
	add_child(humo)
	humo.emitting = true
	get_tree().create_timer(2.5, false).timeout.connect(humo.queue_free)


# ---------- HUD ----------

func _crear_hud() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)

	_hud = _label_base(16)
	_hud.position = Vector2(16, 12)
	capa.add_child(_hud)

	_mensaje = _label_base(22)
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
	_hud.text = vidas_txt + "Velas %d/%d   Flores %d/%d   Pétalos %d/%d   Copal x%d  [Q]" % [
		recogidos["vela"], total["vela"], recogidos["flor"], total["flor"],
		recogidos["petalos"], total["petalos"], copal]


func _asegurar_accion(nombre: String, tecla: Key) -> void:
	if InputMap.has_action(nombre):
		return
	InputMap.add_action(nombre)
	var ev := InputEventKey.new()
	ev.physical_keycode = tecla
	InputMap.action_add_event(nombre, ev)
