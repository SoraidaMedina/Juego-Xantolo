extends Node2D

@export var distancia_x: float = 70.0
@export var altura: float = -90.0
@export var suavidad: float = 4.0
## Actívalo en los niveles donde solo da la pista y luego se va (ej. nivel 2)
@export var se_despide: bool = false
## Segundos que acompaña a Xochik antes de irse
@export var tiempo_antes_de_irse: float = 5.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var ocupada: bool = false
var tiempo: float = 0.0
var _yendose: bool = false


func _ready() -> void:
	if se_despide:
		_despedirse()


func _process(delta: float) -> void:
	tiempo += delta
	if _yendose:
		# Sube flotando mientras se desvanece
		global_position.y -= 25.0 * delta
		return

	var jugador := get_tree().get_first_node_in_group("jugador") as Node2D
	if jugador == null:
		return

	var mira_izquierda: bool = (jugador.get_node("AnimatedSprite2D") as AnimatedSprite2D).flip_h
	var lado := -1.0 if mira_izquierda else 1.0
	var objetivo := jugador.global_position + Vector2(lado * distancia_x, altura + sin(tiempo * 3.0) * 6.0)

	var antes_x := global_position.x
	global_position = global_position.lerp(objetivo, 1.0 - exp(-suavidad * delta))
	var rapidez_x: float = absf(global_position.x - antes_x) / delta

	anim.flip_h = mira_izquierda

	if InputMap.has_action("guiar") and Input.is_action_just_pressed("guiar"):
		_hacer("guide", 1.5)
	if InputMap.has_action("luz") and Input.is_action_just_pressed("luz"):
		_hacer("light", 2.0)

	if not ocupada:
		anim.play("float" if rapidez_x > 15.0 else "idle")


func _hacer(nombre: String, duracion: float) -> void:
	if ocupada:
		return
	ocupada = true
	anim.play(nombre)
	await get_tree().create_timer(duracion, false).timeout
	ocupada = false


## Da la pista (animación "guide"), brilla y se desvanece hacia arriba
func _despedirse() -> void:
	_hacer("guide", tiempo_antes_de_irse)
	await get_tree().create_timer(tiempo_antes_de_irse, false).timeout
	ocupada = true
	anim.play("light")
	await get_tree().create_timer(0.6, false).timeout
	_yendose = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 1.5)
	await tw.finished
	queue_free()
