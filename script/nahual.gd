extends CharacterBody2D
## El Nahual — depredador de sigilo (nivel 3).
## Patrulla y cada cierto tiempo se detiene a VIGILAR. Antes avisa con "!".
## Mientras vigila: si Xochik se mueve o tiene la luz prendida (y está cerca), la caza.
## Agachada dentro de un Escondite está a salvo.

signal vigilancia(activa: bool)

@export var velocidad: float = 55.0
@export var distancia_patrulla: float = 260.0
## Distancia a la que percibe movimiento o luz mientras vigila
@export var rango_vision: float = 300.0
@export var rango_contacto: float = 55.0
## Qué tan arriba o abajo de él puede percibirla (si Xochik sube a las rocas)
@export var alto_vision: float = 260.0
## Segundos entre una vigilancia y otra (al azar entre min y max)
@export var espera_min: float = 5.0
@export var espera_max: float = 8.0
## Segundos de aviso antes de vigilar: el "momento preciso" para quedarse quieta y ocultar la luz
@export var tiempo_aviso: float = 1.0
## Segundos que se queda vigilando
@export var tiempo_vigilando: float = 2.0

var gravedad: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var inicio_x: float
var dir: float = 1.0
var estado: String = "patrulla"   # patrulla | aviso | vigilando | cazando
var _t: float = 0.0
var _icono: Label


func _ready() -> void:
	add_to_group("nahual")
	inicio_x = global_position.x
	_icono = Label.new()
	_icono.add_theme_font_size_override("font_size", 24)
	_icono.add_theme_color_override("font_outline_color", Color.BLACK)
	_icono.add_theme_constant_override("outline_size", 6)
	_icono.position = Vector2(-8, -120)
	_icono.visible = false
	add_child(_icono)
	_programar_vigilancia()
	# No choca físicamente con Xochik: pasa junto a ella (si está escondida, no la toca)
	await get_tree().process_frame
	var j := get_tree().get_first_node_in_group("jugador") as PhysicsBody2D
	if j:
		add_collision_exception_with(j)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravedad * delta

	var jugador := get_tree().get_first_node_in_group("jugador") as CharacterBody2D
	_t -= delta

	var nivel = get_tree().get_first_node_in_group("nivel")
	var activo: bool = nivel == null or nivel.get("_jugando") != false

	match estado:
		"patrulla":
			_patrullar()
			if _t <= 0.0 and activo:
				estado = "aviso"
				_t = tiempo_aviso
				_mostrar_icono("!", Color(0.9, 0.9, 0.9))
				Juego.sfx("latido", -2.0)
				_play(["detect", "cry", "idle"])
		"aviso":
			velocity.x = 0.0
			# Parpadea el aviso
			_icono.visible = int(_t * 8.0) % 2 == 0
			if _t <= 0.0:
				estado = "vigilando"
				_t = tiempo_vigilando
				_mostrar_icono("!", Color(1.0, 0.45, 0.3))
				vigilancia.emit(true)
				Juego.sfx("grunido", -3.0)
		"vigilando":
			velocity.x = 0.0
			# Voltea a ambos lados mientras vigila
			anim.flip_h = int(_t * 1.2) % 2 == 0
			if _detecta(jugador):
				_cazar(jugador)
			elif _t <= 0.0:
				_icono.visible = false
				vigilancia.emit(false)
				estado = "patrulla"
				_programar_vigilancia()
		_:
			velocity.x = 0.0

	move_and_slide()
	_revisar_contacto(jugador)


func _patrullar() -> void:
	velocity.x = dir * velocidad
	if global_position.x > inicio_x + distancia_patrulla:
		dir = -1.0
	elif global_position.x < inicio_x - distancia_patrulla:
		dir = 1.0
	elif is_on_wall():
		# Se aleja de la pared (voltear con -dir lo dejaba trabado: seguía "en la pared" un cuadro más)
		var n := signf(get_wall_normal().x)
		if n != 0.0:
			dir = n
	anim.flip_h = dir < 0
	_play(["walk"])


func _programar_vigilancia() -> void:
	_t = randf_range(espera_min, espera_max)


func _detecta(j: CharacterBody2D) -> bool:
	if j == null or j.atrapada or j.esta_escondida() or j.protegida:
		return false
	var dx := absf(j.global_position.x - global_position.x)
	var dy := absf(j.global_position.y - global_position.y)
	if dx > rango_vision or dy > alto_vision:
		return false
	return _delata_presencia(j)


## Xochik "contiene su presencia" si está quieta y con la luz oculta
func _delata_presencia(j: CharacterBody2D) -> bool:
	if j.protegida:
		return false   # amuleto bordado activo
	var se_mueve := absf(j.velocity.x) > 5.0 or not j.is_on_floor()
	var nivel = get_tree().get_first_node_in_group("nivel")
	var luz_prendida: bool = nivel != null and nivel.has_method("luz_visible") and nivel.luz_visible()
	return se_mueve or luz_prendida


func _revisar_contacto(j: CharacterBody2D) -> void:
	if j == null or j.atrapada or estado == "cazando":
		return
	if j.esta_escondida():
		return
	var choco := false
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == j:
			choco = true
	var dx := absf(j.global_position.x - global_position.x)
	var dy := absf(j.global_position.y - global_position.y)
	if choco or (dx < rango_contacto and dy < 80.0):
		# Si contiene su presencia (quieta + luz oculta), el Nahual pasa de largo
		if _delata_presencia(j):
			_cazar(j)


func _cazar(j: CharacterBody2D) -> void:
	estado = "cazando"
	Juego.susto("nahual")
	vigilancia.emit(false)
	_mostrar_icono("!!", Color.WHITE)
	anim.flip_h = j.global_position.x < global_position.x
	_play(["walk"])
	anim.speed_scale = 2.5
	# Se abalanza sobre ella
	var destino_x := j.global_position.x - signf(j.global_position.x - global_position.x) * 30.0
	var tw := create_tween()
	tw.tween_property(self, "global_position:x", destino_x, 0.3).set_ease(Tween.EASE_IN)
	await tw.finished
	anim.speed_scale = 1.0
	j.ser_atrapada()
	await get_tree().create_timer(0.6, false).timeout
	# Se transforma y desaparece en la oscuridad; reaparece en su zona
	_icono.visible = false
	_play(["disappear"])
	var fuera := create_tween()
	fuera.tween_property(anim, "modulate:a", 0.0, 0.8)
	await fuera.finished
	global_position.x = inicio_x
	await get_tree().create_timer(1.0, false).timeout
	var dentro := create_tween()
	dentro.tween_property(anim, "modulate:a", 1.0, 0.8)
	await dentro.finished
	estado = "patrulla"
	_programar_vigilancia()


func _mostrar_icono(txt: String, color: Color) -> void:
	_icono.text = txt
	_icono.modulate = color
	_icono.visible = true


## Reproduce la primera animación que exista de la lista
func _play(nombres: Array) -> void:
	if anim.sprite_frames == null:
		return
	for n in nombres:
		if anim.sprite_frames.has_animation(n):
			anim.play(n)
			return
