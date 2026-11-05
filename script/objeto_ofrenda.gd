@tool
extends Area2D
class_name ObjetoOfrenda
## Objeto recolectable del nivel: velas y flores de la ofrenda, o talismanes (copal, pétalos).
## Arrastra objeto_ofrenda.tscn al nivel, elige "tipo" y "textura" en el Inspector y listo.

signal recogido(objeto: ObjetoOfrenda)

@export_enum("vela", "flor", "copal", "petalos") var tipo: String = "vela"
@export var textura: Texture2D:
	set(valor):
		textura = valor
		if is_node_ready():
			$Sprite2D.texture = valor
@export var escala: float = 0.12:
	set(valor):
		escala = valor
		if is_node_ready():
			$Sprite2D.scale = Vector2.ONE * valor
@export var recoger_automatico: bool = false
## Radio de ruido al recoger (alerta a chaneques cercanos). 0 = silencioso.
@export var ruido_al_recoger: float = 0.0
## Solo copal: vuelve a aparecer en su lugar cuando se usa
@export var reaparece: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var aviso: Label = $Aviso

var _jugador_cerca := false
var _recogido := false
var _t := 0.0


func _ready() -> void:
	sprite.texture = textura
	sprite.scale = Vector2.ONE * escala
	if Engine.is_editor_hint():
		return
	add_to_group("recolectable")
	_t = randf() * TAU  # para que no floten todos sincronizados
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _recogido:
		return
	_t += delta
	# Flota y brilla suave para que se distinga en la penumbra
	sprite.position.y = sin(_t * 2.0) * 3.0
	var brillo := 0.85 + sin(_t * 3.0) * 0.15
	sprite.modulate = Color(brillo, brillo, brillo)
	var jugador = get_tree().get_first_node_in_group("jugador")
	if jugador and jugador.get("atrapada"):
		return
	if _jugador_cerca and Input.is_action_just_pressed("interactuar"):
		recoger()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("jugador"):
		return
	if recoger_automatico:
		recoger()
	else:
		_jugador_cerca = true
		aviso.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("jugador"):
		_jugador_cerca = false
		aviso.visible = false


func recoger() -> void:
	if _recogido:
		return
	_recogido = true
	aviso.visible = false
	set_deferred("monitoring", false)
	recogido.emit(self)

	if ruido_al_recoger > 0.0:
		for c in get_tree().get_nodes_in_group("chaneques"):
			if c.has_method("escuchar_ruido") and c.global_position.distance_to(global_position) <= ruido_al_recoger:
				c.escuchar_ruido(global_position)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(sprite, "position:y", sprite.position.y - 24.0, 0.4)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.4)
	if reaparece and tipo == "copal":
		tw.chain().tween_callback(hide)
	else:
		tw.chain().tween_callback(queue_free)


## La llama el nivel cuando el talismán se usa: vuelve a su lugar
func reaparecer() -> void:
	_recogido = false
	_jugador_cerca = false
	sprite.position.y = 0.0
	sprite.modulate = Color(1, 1, 1, 0)
	show()
	set_deferred("monitoring", true)
	create_tween().tween_property(sprite, "modulate:a", 1.0, 0.6)
