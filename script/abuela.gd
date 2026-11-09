extends Node2D
## La abuela — narra la leyenda y da las instrucciones del nivel; al terminar se desvanece.
## El nivel le pasa los mensajes con decir(). También puede hablar sola con "mensajes_propios".

signal termino

## Si el nivel no le pasa mensajes, dice estos
@export var mensajes_propios: PackedStringArray = []
## Segundos mínimos que se queda cada mensaje ya escrito
@export var segundos_por_mensaje: float = 2.5
## Segundos extra por cada letra (los mensajes largos duran más para leerlos)
@export var segundos_por_letra: float = 0.05
## Letras por segundo del efecto máquina de escribir
@export var letras_por_segundo: float = 22.0
## Pausa al llegar a una coma o a un punto (como cuando alguien habla)
@export var pausa_coma: float = 0.25
@export var pausa_punto: float = 0.5
## Si está activo, cada mensaje espera a que presiones E (no avanza solo)
@export var esperar_tecla: bool = false
## Xochik no se puede mover mientras la abuela habla
@export var congelar_jugador: bool = true
## Ancho del globo de texto (px)
@export var ancho_globo: float = 300.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _globo: PanelContainer
var _texto: Label
var _seguir: Label
var _hablando := false
var _saltar := false


func _ready() -> void:
	add_to_group("abuela")
	_crear_globo()
	anim.play("idle")
	if not mensajes_propios.is_empty():
		await get_tree().process_frame
		decir(mensajes_propios)


func _process(_delta: float) -> void:
	# Siempre voltea a ver a Xochik
	var j := get_tree().get_first_node_in_group("jugador") as Node2D
	if j:
		anim.flip_h = j.global_position.x < global_position.x
	if _hablando and Input.is_action_just_pressed("interactuar"):
		_saltar = true


## El HUD se hace a un lado mientras la abuela habla (para no tapar su globo)
func esta_hablando() -> bool:
	return _hablando


## Dice los mensajes uno por uno y luego se va. Se puede esperar con: await abuela.decir([...])
func decir(mensajes: PackedStringArray) -> void:
	var j = get_tree().get_first_node_in_group("jugador")
	if congelar_jugador and j:
		j.atrapada = true
	_hablando = true
	_globo.visible = true
	_globo.modulate.a = 0.0
	create_tween().tween_property(_globo, "modulate:a", 1.0, 0.3)

	for i in mensajes.size():
		var m: String = mensajes[i]
		await _escribir(m)
		if esperar_tecla:
			await _esperar(INF)
		else:
			await _esperar(segundos_por_mensaje + m.length() * segundos_por_letra)
		# Pequeña transición entre mensajes
		if i < mensajes.size() - 1:
			var f := create_tween()
			f.tween_property(_texto, "modulate:a", 0.0, 0.25)
			await f.finished
			await get_tree().create_timer(0.2, false).timeout
			_texto.modulate.a = 1.0

	_hablando = false
	var tw := create_tween()
	tw.tween_property(_globo, "modulate:a", 0.0, 0.3)
	await tw.finished
	_globo.visible = false
	if congelar_jugador and j:
		j.atrapada = false
	termino.emit()
	_desvanecerse()


func _escribir(txt: String) -> void:
	_texto.text = txt
	_seguir.visible = false
	_saltar = false
	anim.play("talk")
	_texto.visible_characters = 0
	var total := _texto.get_total_character_count()
	var por_letra := 1.0 / letras_por_segundo
	var i := 0
	while i < total and not _saltar:
		i += 1
		_texto.visible_characters = i
		var c := txt[i - 1] if i - 1 < txt.length() else ""
		var espera := por_letra
		if c in [",", ";", ":"]:
			espera += pausa_coma
		elif c in [".", "!", "?", "…"]:
			espera += pausa_punto
		elif c == "\n":
			espera += pausa_coma
		await get_tree().create_timer(espera, false).timeout
	_texto.visible_characters = -1
	_saltar = false
	anim.play("idle")
	_seguir.visible = true


func _esperar(seg: float) -> void:
	# Medio segundo de gracia para que un E de "saltar texto" no se salte también el mensaje
	await get_tree().create_timer(0.3, false).timeout
	_saltar = false
	var t := 0.0
	while t < seg and not _saltar:
		t += get_process_delta_time()
		await get_tree().process_frame
	_saltar = false


func _desvanecerse() -> void:
	# Se vuelve humo de copal: sube un poco y se desvanece
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 1.8)
	tw.tween_property(self, "position:y", position.y - 30.0, 1.8)
	await tw.finished
	queue_free()


func _crear_globo() -> void:
	var alto_sprite := 140.0
	var frames := anim.sprite_frames
	if frames and frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
		alto_sprite = frames.get_frame_texture("idle", 0).get_height() * anim.scale.y

	_globo = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.06, 0.06, 0.07, 0.88)
	estilo.border_color = Color(1.0, 0.85, 0.55, 0.9)   # luz cálida de vela
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 12
	estilo.content_margin_right = 12
	estilo.content_margin_top = 8
	estilo.content_margin_bottom = 8
	_globo.add_theme_stylebox_override("panel", estilo)
	_globo.custom_minimum_size = Vector2(ancho_globo, 0)
	_globo.position = Vector2(-ancho_globo / 2.0, -alto_sprite - 95.0)
	_globo.z_index = 10
	_globo.visible = false

	var caja := VBoxContainer.new()
	_globo.add_child(caja)

	var nombre := Label.new()
	nombre.text = "Abuela"
	nombre.add_theme_font_size_override("font_size", 11)
	nombre.modulate = Color(1.0, 0.85, 0.55)
	caja.add_child(nombre)

	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size = Vector2(ancho_globo - 24, 0)
	_texto.add_theme_font_size_override("font_size", 13)
	caja.add_child(_texto)

	_seguir = Label.new()
	_seguir.text = "[E] ▸"
	_seguir.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_seguir.add_theme_font_size_override("font_size", 10)
	_seguir.modulate = Color(1, 1, 1, 0.6)
	caja.add_child(_seguir)

	add_child(_globo)
