extends CharacterBody2D

@export var velocidad: float = 60.0
@export var distancia_patrulla: float = 200.0
@export var rango_vision: float = 260.0
@export var rango_espalda: float = 60.0
@export var tiempo_alerta: float = 1.2
@export var factor_agachada: float = 0.5
@export var solo_detecta_movimiento: bool = false

var gravedad: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var inicio_x: float
var dir: float = 1.0
var estado: String = "patrulla"
var reloj_alerta: float = 0.0

func _ready() -> void:
	inicio_x = global_position.x

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravedad * delta

	var jugador = get_tree().get_first_node_in_group("jugador")
	var ve_al_jugador: bool = jugador != null and _puede_ver(jugador)

	match estado:
		"patrulla":
			_patrullar()
			if ve_al_jugador:
				estado = "alerta"
				reloj_alerta = 0.0
		"alerta":
			velocity.x = 0.0
			if jugador != null:
				anim.flip_h = jugador.global_position.x < global_position.x
			anim.play("cry")
			if not ve_al_jugador:
				estado = "patrulla"
			else:
				reloj_alerta += delta
				if reloj_alerta >= tiempo_alerta:
					estado = "atrapo"
					jugador.ser_atrapada()
		"atrapo":
			velocity.x = 0.0
			anim.play("idle")
			if jugador == null or not jugador.atrapada:
				estado = "patrulla"

	move_and_slide()

func _patrullar() -> void:
	velocity.x = dir * velocidad
	if global_position.x > inicio_x + distancia_patrulla:
		dir = -1.0
	elif global_position.x < inicio_x - distancia_patrulla:
		dir = 1.0
	elif is_on_wall():
		dir = -dir
	anim.flip_h = dir < 0
	anim.play("walk")

func _puede_ver(jugador) -> bool:
	if jugador.atrapada:
		return false

	var rango: float = rango_vision
	if Input.is_action_pressed("agachar"):
		rango *= factor_agachada
	if solo_detecta_movimiento and absf(jugador.velocity.x) < 1.0:
		rango = 0.0

	var mira_hacia := -1.0 if anim.flip_h else 1.0
	var dx: float = jugador.global_position.x - global_position.x
	if signf(dx) != mira_hacia:
		rango = minf(rango, rango_espalda)

	if global_position.distance_to(jugador.global_position) > rango:
		return false
	return _linea_de_vista(jugador)

func _linea_de_vista(jugador) -> bool:
	var espacio := get_world_2d().direct_space_state
	var consulta := PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, -40), jugador.global_position)
	consulta.exclude = [get_rid()]
	var resultado := espacio.intersect_ray(consulta)
	return resultado.is_empty() or resultado.collider == jugador
