extends CharacterBody2D

signal vidas_cambiadas(vidas: int)
signal sin_vidas

@export var velocidad: float = 150.0
## Agachada camina despacio y en silencio (sigilo)
@export var velocidad_agachada: float = 55.0
## Anillo que muestra hasta dónde se oyen tus pasos (solo en niveles con chaneques)
@export var mostrar_ruido: bool = true
## Debe ser igual a "rango_oido" de los chaneques: el anillo muestra exactamente hasta dónde te oyen
@export var radio_ruido: float = 190.0
@export var fuerza_salto: float = -350.0
@export var vidas_max: int = 3
## Actívalo en los niveles donde Xochik empieza mirando a la izquierda
@export var mirar_izquierda_al_inicio: bool = false
## Px por debajo del fondo a los que se considera que cayó al vacío
@export var margen_caida: float = 60.0
## Posición y tamaño del objeto que carga en la mano (nivel 2)
@export var offset_mano: Vector2 = Vector2(14, -6)
@export var escala_mano: float = 0.05

var gravedad: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var punto_reaparicion: Vector2
var atrapada: bool = false
var vidas: int
var agachada: bool = false
var en_escondite: bool = false
var objeto_en_mano: Node = null   # pertenencia que carga (nivel 2)
var _mano: Sprite2D
var _ruido_caida := 0.0      # segundos de ruido fuerte al caer de un salto
var _en_suelo_antes := true
var _radio_visible := 0.0
var _te_oyen := false   # algún chaneque está dentro del anillo
var _t_paso := 0.0


func _ready() -> void:
	add_to_group("jugador")
	punto_reaparicion = global_position
	vidas = vidas_max
	anim.flip_h = mirar_izquierda_al_inicio
	_mano = Sprite2D.new()
	_mano.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mano.z_index = 1
	_mano.visible = false
	add_child(_mano)


## Escondida = agachada dentro de un escondite
func esta_escondida() -> bool:
	return agachada and en_escondite


func _physics_process(delta: float) -> void:
	_revisar_caida()
	if not is_on_floor():
		velocity.y += gravedad * delta

	if atrapada:
		velocity.x = 0.0
		move_and_slide()
		return

	agachada = is_on_floor() and Input.is_action_pressed("agachar")
	var dir := Input.get_axis("izquierda", "derecha")

	if Input.is_action_just_pressed("saltar") and is_on_floor() and not agachada:
		velocity.y = fuerza_salto
		Juego.sfx("salto", -4.0, randf_range(0.95, 1.05))

	velocity.x = dir * (velocidad_agachada if agachada else velocidad)
	move_and_slide()
	if is_on_floor() and not _en_suelo_antes:
		_ruido_caida = 0.35
		Juego.sfx("caida", -6.0, randf_range(0.9, 1.1))
	_sonido_pasos(delta)
	_en_suelo_antes = is_on_floor()
	_ruido_caida = maxf(_ruido_caida - delta, 0.0)
	_actualizar_animacion(dir)

	# Se oscurece cuando está escondida
	anim.self_modulate = Color(0.45, 0.45, 0.5) if esta_escondida() else Color.WHITE


func _sonido_pasos(delta: float) -> void:
	if not is_on_floor() or absf(velocity.x) < 10.0:
		_t_paso = 0.12
		return
	_t_paso -= delta
	if _t_paso <= 0.0:
		_t_paso = 0.5 if agachada else 0.32
		# Agachada casi no se oye
		Juego.sfx("paso", -24.0 if agachada else -9.0, randf_range(0.85, 1.15))


## 0 = silencio (quieta o agachada) · 1 = pasos · 1.6 = saltar / caer
func nivel_ruido() -> float:
	if atrapada:
		return 0.0
	if _ruido_caida > 0.0 or not is_on_floor():
		return 1.6
	if agachada:
		return 0.0
	return 1.0 if absf(velocity.x) > 10.0 else 0.0


func _process(delta: float) -> void:
	# Anillo de ruido
	var objetivo := 0.0
	if mostrar_ruido and get_tree().has_group("chaneques"):
		objetivo = nivel_ruido() * radio_ruido
	_radio_visible = lerpf(_radio_visible, objetivo, 1.0 - exp(-8.0 * delta))
	_te_oyen = false
	if objetivo > 0.0:
		for c in get_tree().get_nodes_in_group("chaneques"):
			if c.visible and c.anim.modulate.a > 0.5 and c.global_position.distance_to(global_position) < objetivo:
				_te_oyen = true
	# En sigilo (agachada entre chaneques) Xochik se oscurece un poco: señal de que no la oyen
	var sigilo := agachada and get_tree().has_group("chaneques")
	anim.modulate = anim.modulate.lerp(Color(0.62, 0.62, 0.62) if sigilo else Color.WHITE, 1.0 - exp(-10.0 * delta))
	queue_redraw()
	if _mano.visible:
		_mano.position = Vector2(-offset_mano.x if anim.flip_h else offset_mano.x, offset_mano.y)
		_mano.flip_h = anim.flip_h


func _actualizar_animacion(dir: float) -> void:
	if dir != 0:
		anim.flip_h = dir < 0
	if agachada:
		anim.play("crouch")
	elif not is_on_floor():
		anim.play("idle")
	elif dir != 0:
		anim.play("walk")
	else:
		anim.play("idle")


func _draw() -> void:
	if _radio_visible < 6.0:
		return
	var a := clampf(_radio_visible / (radio_ruido * 1.6), 0.0, 1.0)
	if _te_oyen:
		# Un chaneque está dentro: el anillo se marca fuerte y punteado
		var pasos := 40
		for i in pasos:
			if i % 2 == 0:
				var a0 := TAU * i / pasos
				draw_arc(Vector2.ZERO, _radio_visible, a0, a0 + TAU / pasos, 4, Color(1, 1, 1, 0.75), 3.0, true)
	else:
		draw_arc(Vector2.ZERO, _radio_visible, 0.0, TAU, 64, Color(1, 1, 1, 0.16 + 0.14 * a), 2.0, true)


func mostrar_en_mano(tex: Texture2D) -> void:
	_mano.texture = tex
	_mano.scale = Vector2.ONE * escala_mano
	_mano.visible = true


func ocultar_mano() -> void:
	_mano.visible = false


## Si cae más abajo del límite de la cámara (el fondo), pierde una vida
func _revisar_caida() -> void:
	if atrapada:
		return
	var limite := 100000.0
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam and cam.limit_bottom < 1000000:
		limite = cam.limit_bottom + margen_caida
	if global_position.y > limite:
		ser_atrapada("¡Caíste al vacío!")


func ser_atrapada(motivo: String = "") -> void:
	if atrapada:
		return
	atrapada = true
	Juego.sfx("atrapada", -3.0)
	vidas -= 1
	vidas_cambiadas.emit(vidas)
	_aviso_vida(motivo)
	anim.play("idle")

	var golpe := create_tween()
	golpe.tween_property(anim, "modulate", Color(1, 0.4, 0.4), 0.1)
	golpe.tween_property(anim, "modulate", Color.WHITE, 0.1)
	await golpe.finished

	if vidas <= 0:
		var fin := create_tween()
		fin.tween_property(anim, "modulate:a", 0.0, 0.8)
		sin_vidas.emit()
		return

	var salida := create_tween()
	salida.tween_property(anim, "modulate:a", 0.0, 0.5)
	await salida.finished
	global_position = punto_reaparicion
	velocity = Vector2.ZERO
	await get_tree().create_timer(0.3, false).timeout
	var entrada := create_tween()
	entrada.tween_property(anim, "modulate:a", 1.0, 0.5)
	await entrada.finished
	atrapada = false


## Texto flotante "-1 vida" en pantalla
func _aviso_vida(motivo: String) -> void:
	var capa := CanvasLayer.new()
	capa.layer = 50
	get_tree().current_scene.add_child(capa)
	var l := Label.new()
	l.text = (motivo + "\n" if motivo != "" else "") + "-1 vida"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	capa.add_child(l)
	var tw := capa.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(capa.queue_free)
