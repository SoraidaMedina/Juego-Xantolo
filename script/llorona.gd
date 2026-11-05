extends CharacterBody2D
## La Llorona — patrulla el río. Si ve a Xochik, la persigue.
## Si la alcanza: con la pertenencia correcta encuentra paz; si no, Xochik pierde una vida.
## Agacharse dentro de un Escondite la vuelve invisible para ella.

signal calmada

@export var velocidad: float = 50.0
@export var velocidad_persecucion: float = 115.0
@export var distancia_patrulla: float = 250.0
@export var rango_vision: float = 260.0
@export var rango_contacto: float = 60.0
## Segundos que busca antes de volver a patrullar si te pierde de vista
@export var tiempo_busqueda: float = 2.5
## Flota como espíritu: sin gravedad, atraviesa plataformas y persigue en cualquier dirección
@export var flota: bool = true
## Qué tanto sube y baja mientras flota (px)
@export var amplitud_flote: float = 12.0
## (Flotando) A qué distancia de Xochik se detiene y ocurre el encuentro
@export var distancia_encuentro: float = 110.0

var gravedad: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var inicio_x: float
var dir: float = 1.0
var estado: String = "patrulla"   # patrulla | persecucion | buscando | reaccion | calmada
var _t_busqueda := 0.0
var _icono: Label
var _altura_base: float
var _t_flote := 0.0


func _ready() -> void:
	add_to_group("llorona")
	inicio_x = global_position.x
	_altura_base = global_position.y
	if flota:
		collision_mask = 0   # atraviesa suelo y plataformas
	_icono = Label.new()
	_icono.add_theme_font_size_override("font_size", 22)
	_icono.add_theme_color_override("font_outline_color", Color.BLACK)
	_icono.add_theme_constant_override("outline_size", 5)
	_icono.position = Vector2(-6, -110)
	_icono.visible = false
	add_child(_icono)


func _physics_process(delta: float) -> void:
	_t_flote += delta
	if flota:
		velocity.y = 0.0
	elif not is_on_floor():
		velocity.y += gravedad * delta

	var jugador := get_tree().get_first_node_in_group("jugador") as CharacterBody2D

	match estado:
		"patrulla":
			_patrullar()
			if _ve_jugador(jugador, false):
				estado = "persecucion"
				_mostrar_icono("!", Color(1, 0.4, 0.4))
		"persecucion":
			if _ve_jugador(jugador, true):
				_t_busqueda = 0.0
				dir = signf(jugador.global_position.x - global_position.x)
				if flota:
					var hacia := (jugador.global_position + Vector2(0, -20) - global_position).normalized()
					velocity = hacia * velocidad_persecucion
				else:
					velocity.x = dir * velocidad_persecucion
				anim.flip_h = dir < 0
				anim.speed_scale = 1.6
				_play("walk")
			else:
				estado = "buscando"
				_t_busqueda = 0.0
				_mostrar_icono("?", Color(1, 0.85, 0.55))
		"buscando":
			velocity.x = 0.0
			if flota:
				velocity.y = (_altura_base - global_position.y) * 1.5
			anim.speed_scale = 1.0
			_play("idle")
			_t_busqueda += delta
			if _ve_jugador(jugador, false):
				estado = "persecucion"
				_mostrar_icono("!", Color(1, 0.4, 0.4))
			elif _t_busqueda >= tiempo_busqueda:
				estado = "patrulla"
				_icono.visible = false
		_:
			velocity.x = 0.0

	move_and_slide()
	_revisar_contacto(jugador)


func _patrullar() -> void:
	anim.speed_scale = 1.0
	velocity.x = dir * velocidad
	if global_position.x > inicio_x + distancia_patrulla:
		dir = -1.0
	elif global_position.x < inicio_x - distancia_patrulla:
		dir = 1.0
	elif is_on_wall():
		dir = -dir
	anim.flip_h = dir < 0
	_play("walk")
	if flota:
		var objetivo_y := _altura_base + sin(_t_flote * 1.8) * amplitud_flote
		velocity.y = (objetivo_y - global_position.y) * 3.0


## persiguiendo = true: ya la vio, la sigue aunque esté detrás
func _ve_jugador(jugador: CharacterBody2D, persiguiendo: bool) -> bool:
	if jugador == null or jugador.atrapada or jugador.esta_escondida():
		return false
	var dx := jugador.global_position.x - global_position.x
	var dy := absf(jugador.global_position.y - global_position.y)
	var dist := Vector2(dx, dy).length() if flota else absf(dx)
	if dy > (rango_vision if flota else 120.0):
		return false
	if persiguiendo:
		return dist < rango_vision * 1.5
	var de_frente := signf(dx) == dir
	return dist < rango_vision and (de_frente or dist < 70.0)


func _revisar_contacto(jugador: CharacterBody2D) -> void:
	if jugador == null or jugador.atrapada:
		return
	# Escondida = a salvo, aunque la Llorona pase encima de ella
	if jugador.esta_escondida():
		return
	if estado == "reaccion" or estado == "calmada":
		return
	var choco := false
	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == jugador:
			choco = true
	var dx := absf(jugador.global_position.x - global_position.x)
	var dy := absf(jugador.global_position.y - global_position.y)
	var toca := Vector2(dx, dy).length() < distancia_encuentro if flota else (dx < rango_contacto and dy < 80.0)
	if choco or toca:
		_encuentro(jugador)


func _encuentro(jugador: CharacterBody2D) -> void:
	velocity = Vector2.ZERO
	if flota:
		# Se detiene frente a ella, a una distancia respetuosa
		var lado := signf(global_position.x - jugador.global_position.x)
		if lado == 0.0:
			lado = 1.0
		var frente := jugador.global_position + Vector2(lado * distancia_encuentro, -20.0)
		create_tween().tween_property(self, "global_position", frente, 0.4).set_ease(Tween.EASE_OUT)
	var obj = jugador.objeto_en_mano
	if obj and obj.es_correcto:
		_calmarse(jugador, obj)
		return
	# Señuelo o manos vacías: grito y Xochik pierde una vida
	estado = "reaccion"
	anim.speed_scale = 1.0
	_mostrar_icono("!", Color(1, 0.4, 0.4))
	anim.flip_h = jugador.global_position.x < global_position.x
	_play("cry")
	if obj:
		jugador.objeto_en_mano = null
		jugador.ocultar_mano()
		obj.devolver()
	jugador.ser_atrapada()
	await get_tree().create_timer(1.8).timeout
	_icono.visible = false
	if estado == "reaccion":
		estado = "patrulla"


func _calmarse(jugador: CharacterBody2D, obj: Node) -> void:
	estado = "calmada"
	velocity.x = 0.0
	anim.speed_scale = 1.0
	_icono.visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	jugador.objeto_en_mano = null
	jugador.ocultar_mano()
	obj.queue_free()
	anim.flip_h = jugador.global_position.x < global_position.x
	_play("cry")
	calmada.emit()
	await get_tree().create_timer(2.5).timeout
	_play("disappear")
	var tw := create_tween()
	tw.tween_property(anim, "modulate:a", 0.0, 1.5)
	await tw.finished
	queue_free()


func _mostrar_icono(txt: String, color: Color) -> void:
	_icono.text = txt
	_icono.modulate = color
	_icono.visible = true


func _play(nombre: String) -> void:
	if anim.sprite_frames and anim.sprite_frames.has_animation(nombre):
		anim.play(nombre)
