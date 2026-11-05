extends CharacterBody2D
## Chaneque — presencia traviesa que reacciona al RUIDO.
## Si Xochik se mueve o salta cerca, el chaneque empieza a sospechar.
## Si la sospecha se llena, la atrapa (regresa al punto de reaparición).
## Quedarse quieta o agachada = silencio. El copal lo dispersa un rato.

@export var velocidad: float = 60.0
@export var distancia_patrulla: float = 200.0
## Distancia a la que escucha los pasos de Xochik
@export var rango_oido: float = 180.0
## Segundos de ruido continuo antes de atraparla
@export var tiempo_para_detectar: float = 1.2
## Segundos que tarda en volver después del copal
@export var tiempo_dispersado: float = 6.0
## Distancia a la que el chaneque la "toca" y la atrapa aunque esté quieta
@export var rango_contacto: float = 60.0

var gravedad: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var inicio_x: float
var dir: float = 1.0
var estado: String = "patrulla"   # patrulla | alerta | riendo | dispersado
var sospecha: float = 0.0
var _icono: Label


func _ready() -> void:
	add_to_group("chaneques")
	inicio_x = global_position.x
	_icono = Label.new()
	_icono.add_theme_font_size_override("font_size", 20)
	_icono.add_theme_color_override("font_outline_color", Color.BLACK)
	_icono.add_theme_constant_override("outline_size", 5)
	_icono.position = Vector2(-6, -80)
	_icono.visible = false
	add_child(_icono)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravedad * delta

	match estado:
		"patrulla":
			_patrullar()
			_escuchar_jugador(delta)
		"alerta":
			velocity.x = 0.0
			_escuchar_jugador(delta)
		_:
			velocity.x = 0.0

	move_and_slide()
	_revisar_choque()


## Si el chaneque choca físicamente con Xochik, la atrapa (aunque esté quieta)
func _revisar_choque() -> void:
	if estado != "patrulla" and estado != "alerta":
		return
	for i in get_slide_collision_count():
		var otro = get_slide_collision(i).get_collider()
		if otro and otro.is_in_group("jugador") and not otro.get("atrapada"):
			_atrapar(otro)
			return


func _patrullar() -> void:
	velocity.x = dir * velocidad
	if global_position.x > inicio_x + distancia_patrulla:
		dir = -1.0
	elif global_position.x < inicio_x - distancia_patrulla:
		dir = 1.0
	elif is_on_wall():
		dir = -dir
	anim.flip_h = dir < 0
	_play("walk")


func _escuchar_jugador(delta: float) -> void:
	var jugador := get_tree().get_first_node_in_group("jugador") as CharacterBody2D
	if jugador == null or jugador.get("atrapada"):
		sospecha = 0.0
		return

	var distancia := global_position.distance_to(jugador.global_position)
	var dx := absf(jugador.global_position.x - global_position.x)
	var dy := absf(jugador.global_position.y - global_position.y)
	if dx < rango_contacto and dy < 80.0:
		_atrapar(jugador)
		return
	var cerca := distancia < rango_oido
	var hace_ruido := absf(jugador.velocity.x) > 10.0 or not jugador.is_on_floor()

	if cerca and hace_ruido:
		sospecha += delta
		if estado == "patrulla":
			estado = "alerta"
		_mostrar_icono("?")
		anim.flip_h = jugador.global_position.x < global_position.x
		_play("cry")
		if sospecha >= tiempo_para_detectar:
			_atrapar(jugador)
	else:
		# Si Xochik se queda quieta, la sospecha baja y vuelve a patrullar
		sospecha = maxf(sospecha - delta * 0.8, 0.0)
		if estado == "alerta" and sospecha == 0.0:
			estado = "patrulla"
			_icono.visible = false


func _atrapar(jugador: Node) -> void:
	estado = "riendo"
	sospecha = 0.0
	_mostrar_icono("!")
	if jugador.has_method("ser_atrapada"):
		jugador.ser_atrapada()
	_play("cry")
	await get_tree().create_timer(1.5).timeout
	_icono.visible = false
	if estado == "riendo":
		estado = "patrulla"


## Lo llaman los objetos al recogerse (si tienen ruido_al_recoger > 0)
func escuchar_ruido(pos: Vector2) -> void:
	if estado != "patrulla" and estado != "alerta":
		return
	estado = "alerta"
	sospecha += tiempo_para_detectar * 0.4
	_mostrar_icono("?")
	anim.flip_h = pos.x < global_position.x
	_play("cry")


## Lo llama el nivel cuando Xochik usa copal [Q]
func dispersar() -> void:
	if estado == "dispersado":
		return
	estado = "dispersado"
	sospecha = 0.0
	_icono.visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	_play("disappear")
	var tw := create_tween()
	tw.tween_property(anim, "modulate:a", 0.0, 0.8)
	await tw.finished
	await get_tree().create_timer(tiempo_dispersado).timeout
	global_position.x = inicio_x
	$CollisionShape2D.set_deferred("disabled", false)
	var vuelta := create_tween()
	vuelta.tween_property(anim, "modulate:a", 1.0, 0.8)
	await vuelta.finished
	estado = "patrulla"


func _mostrar_icono(txt: String) -> void:
	_icono.text = txt
	_icono.modulate = Color(1.0, 0.85, 0.55) if txt == "?" else Color(1.0, 0.4, 0.4)
	_icono.visible = true


func _play(nombre: String) -> void:
	if anim.sprite_frames and anim.sprite_frames.has_animation(nombre):
		anim.play(nombre)
	elif anim.sprite_frames and anim.sprite_frames.has_animation("idle"):
		anim.play("idle")
