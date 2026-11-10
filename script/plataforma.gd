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
## Piedra floja: tiembla cuando Xochik se para encima, se hunde y al rato vuelve a salir
@export var se_hunde: bool = false
## Segundos que aguanta a Xochik antes de hundirse
@export var aguante: float = 0.6
## Segundos que pasa bajo el agua antes de volver a salir
@export var tiempo_abajo: float = 2.0

## Avisa al nivel la primera vez que empieza a hundirse (para explicarlo)
signal empieza_a_hundirse

const HUNDIDO_MAX := 46.0

var _origen: Vector2
var _t := 0.0
var _estado := "arriba"  # arriba, temblando, hundiendo, abajo, subiendo
var _cuenta := 0.0
var _bajada := 0.0
var _jugador: CharacterBody2D


func _ready() -> void:
	$Sprite2D.texture = textura
	$Sprite2D.scale = Vector2.ONE * escala
	$CollisionShape2D.shape.size = tamano_colision
	$CollisionShape2D.position.y = ajuste_colision_y
	if se_hunde:
		$Sprite2D.modulate = Color(0.78, 0.78, 0.82)  # más oscura y con musgo: se ve floja
	if Engine.is_editor_hint():
		return
	_origen = position
	_t = randf() * TAU


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta * velocidad
	var pos := _origen + Vector2(sin(_t * 0.6) * recorrido_x, sin(_t * 2.0) * flote)
	if se_hunde:
		pos += _hundir(delta)
	position = pos


func _hundir(delta: float) -> Vector2:
	match _estado:
		"arriba":
			if _jugador_encima():
				_estado = "temblando"
				_cuenta = aguante
				empieza_a_hundirse.emit()
		"temblando":
			_cuenta -= delta
			if _cuenta <= 0.0:
				_estado = "hundiendo"
				Juego.sfx("caida", -10.0, 0.7)
			return Vector2(randf_range(-1.5, 1.5), 0.0)
		"hundiendo":
			_bajada = minf(_bajada + delta * 80.0, HUNDIDO_MAX)
			if _bajada > 12.0:
				$CollisionShape2D.set_deferred("disabled", true)
			if _bajada >= HUNDIDO_MAX:
				_estado = "abajo"
				_cuenta = tiempo_abajo
		"abajo":
			_cuenta -= delta
			if _cuenta <= 0.0:
				_estado = "subiendo"
		"subiendo":
			_bajada = maxf(_bajada - delta * 50.0, 0.0)
			if _bajada <= 0.0:
				$CollisionShape2D.set_deferred("disabled", false)
				_estado = "arriba"
	$Sprite2D.modulate.a = 1.0 - _bajada / HUNDIDO_MAX * 0.85
	return Vector2(0.0, _bajada)


func _jugador_encima() -> bool:
	if _jugador == null:
		_jugador = get_tree().get_first_node_in_group("jugador") as CharacterBody2D
	if _jugador == null or not _jugador.is_on_floor():
		return false
	for i in _jugador.get_slide_collision_count():
		if _jugador.get_slide_collision(i).get_collider() == self:
			return true
	return false
