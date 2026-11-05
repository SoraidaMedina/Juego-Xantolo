@tool
extends AnimatableBody2D
## Plataforma sobre el agua (piedra, tronco). Flota un poco y puede moverse de lado a lado.
## Es de un solo sentido: Xochik puede saltar desde abajo y pararse encima.

@export var textura: Texture2D:
	set(v):
		textura = v
		if is_node_ready():
			$Sprite2D.texture = v
@export var escala: float = 0.15:
	set(v):
		escala = v
		if is_node_ready():
			$Sprite2D.scale = Vector2.ONE * v
## Ancho y alto de la parte donde se para Xochik
@export var tamano_colision: Vector2 = Vector2(90, 14):
	set(v):
		tamano_colision = v
		if is_node_ready():
			$CollisionShape2D.shape.size = v
## Sube o baja la colisión para que coincida con la superficie de la imagen
@export var ajuste_colision_y: float = -10.0:
	set(v):
		ajuste_colision_y = v
		if is_node_ready():
			$CollisionShape2D.position.y = v
## Px que sube y baja (como si flotara en el agua). 0 = quieta
@export var flote: float = 3.0
## Px que se mueve de lado a lado. 0 = fija
@export var recorrido_x: float = 0.0
@export var velocidad: float = 1.0

var _origen: Vector2
var _t := 0.0


func _ready() -> void:
	$Sprite2D.texture = textura
	$Sprite2D.scale = Vector2.ONE * escala
	$CollisionShape2D.shape.size = tamano_colision
	$CollisionShape2D.position.y = ajuste_colision_y
	if Engine.is_editor_hint():
		return
	_origen = position
	_t = randf() * TAU


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta * velocidad
	position = _origen + Vector2(sin(_t * 0.6) * recorrido_x, sin(_t * 2.0) * flote)
