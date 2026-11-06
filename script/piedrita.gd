extends Node2D
## Piedrita que lanza Xochik [R]: vuela en arco y, al caer, hace ruido.
## Los chaneques que la oyen van a investigar ese punto (sirve para distraerlos y pasar).

const GRAVEDAD := 900.0

var velocidad := Vector2.ZERO
var _sprite: Sprite2D
var _vida := 3.0


func lanzar(desde: Vector2, direccion: float) -> void:
	global_position = desde
	velocidad = Vector2(direccion * 330.0, -300.0)


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/pueblo/piedrita.png")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	_vida -= delta
	if _vida <= 0.0:
		queue_free()
		return
	velocidad.y += GRAVEDAD * delta
	var desde := global_position
	var hasta := desde + velocidad * delta
	# ¿Choca con el piso, una roca o una pared? (capa 1 = mundo)
	var consulta := PhysicsRayQueryParameters2D.create(desde, hasta, 1)
	var jugador := get_tree().get_first_node_in_group("jugador") as CollisionObject2D
	if jugador:
		consulta.exclude = [jugador.get_rid()]
	var choque := get_world_2d().direct_space_state.intersect_ray(consulta)
	if choque.is_empty():
		global_position = hasta
		_sprite.rotation += delta * 12.0
		return
	global_position = choque.position
	_caer()


func _caer() -> void:
	set_physics_process(false)
	Juego.sfx("piedrita", -2.0, randf_range(0.9, 1.1))
	for c in get_tree().get_nodes_in_group("chaneques"):
		if c.has_method("distraer"):
			c.distraer(global_position)
	# Ondas de sonido para que se vea dónde cayó
	for i in 2:
		var onda := _Onda.new()
		onda.retraso = i * 0.18
		add_child(onda)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


class _Onda extends Node2D:
	var retraso := 0.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var t := _t - retraso
		if t < 0.0 or t > 0.8:
			return
		var r := 8.0 + t * 90.0
		draw_arc(Vector2.ZERO, r, PI, TAU, 24, Color(1, 1, 1, 0.5 * (1.0 - t / 0.8)), 2.0)
