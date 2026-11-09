extends Node2D
## Pasaje oculto de las ánimas: sus piedras (los hijos de este nodo) no se ven ni se pisan
## hasta que el humo del copal lo revela. Mientras, en el aire flotan motas tenues como pista.
## Uso: pon plataformas como hijas de este nodo; el nivel llama a revelar() al quemar copal.

## Grupo con el que el nivel lo encuentra ("oculto_copal" u "oculto_petalos")
@export var revelado_por: String = "copal"
## Tamaño de la zona donde aparecen las motas de pista
@export var zona_pista: Vector2 = Vector2(220, 180)
@export var centro_pista: Vector2 = Vector2.ZERO

var _oculto := true
var _capas := {}
var _motas: CPUParticles2D


func _ready() -> void:
	add_to_group("oculto_" + revelado_por)
	modulate.a = 0.0
	for c in get_children():
		if c is CollisionObject2D:
			var co := c as CollisionObject2D
			_capas[co] = co.collision_layer
			co.collision_layer = 0
	_motas = CPUParticles2D.new()
	_motas.amount = 14
	_motas.lifetime = 3.0
	_motas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motas.emission_rect_extents = zona_pista * 0.5
	_motas.gravity = Vector2(0, -5)
	_motas.initial_velocity_min = 2.0
	_motas.initial_velocity_max = 8.0
	_motas.scale_amount_min = 1.5
	_motas.scale_amount_max = 2.5
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.add_point(0.5, Color(1, 1, 1, 0.3))
	g.set_color(1, Color(1, 1, 1, 0.0))
	_motas.color_ramp = g
	# Las motas van en el nivel (no dentro del pasaje) para verse aunque él esté invisible
	_motas.position = position + centro_pista
	get_parent().add_child.call_deferred(_motas)


func esta_oculto() -> bool:
	return _oculto


func revelar() -> void:
	if not _oculto:
		return
	_oculto = false
	remove_from_group("oculto_" + revelado_por)
	for co in _capas:
		(co as CollisionObject2D).collision_layer = _capas[co]
	_motas.emitting = false
	get_tree().create_timer(3.5, false).timeout.connect(_motas.queue_free)
	Juego.sfx("vela", -3.0, 0.8)
	# Las piedras aparecen una por una, de abajo hacia arriba
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	var i := 0
	for c in get_children():
		if c is CanvasItem:
			var ci := c as CanvasItem
			ci.modulate.a = 0.0
			tw.parallel().tween_property(ci, "modulate:a", 1.0, 0.6).set_delay(0.25 * i)
			_destello(ci)
			i += 1


func _destello(nodo: CanvasItem) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = 16
	p.lifetime = 1.0
	p.spread = 180.0
	p.gravity = Vector2(0, -25)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	p.damping_min = 30.0
	p.damping_max = 50.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.9, 0.9, 0.9))
	g.set_color(1, Color(0.6, 0.6, 0.6, 0.0))
	p.color_ramp = g
	nodo.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6, false).timeout.connect(p.queue_free)
