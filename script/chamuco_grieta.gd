extends Node2D
## Grieta del suelo de la cueva. Cada tanto brilla y gruñe (aviso) y un chamuco sale de golpe.
## Si toca a Xochik, pierde una vida. Hay que esperar a que se esconda y pasar rápido.
## Pon el nodo sobre el piso (position.y = y del suelo).

@export var calma_min: float = 2.2
@export var calma_max: float = 3.4
## Segundos que la grieta brilla y gruñe antes de que salga
@export var aviso: float = 0.9
## Segundos que el chamuco se queda afuera
@export var afuera: float = 1.1
## Segundos de desfase al empezar (para que dos grietas no salgan juntas)
@export var desfase: float = 0.0

const GRIETA := preload("res://assets/cueva/grieta.png")
const CHAMUCO := preload("res://assets/cueva/chamuco_grito.png")

var estado := "calma"
var _t := 0.0
var _salida := 0.0          # 0 = escondido, 1 = afuera
var _grieta: Sprite2D
var _chamuco: Sprite2D
var _area: Area2D
var _luz: PointLight2D
var _polvo: CPUParticles2D


func _ready() -> void:
	add_to_group("grietas")
	_t = randf_range(calma_min, calma_max) + desfase

	_luz = PointLight2D.new()
	_luz.texture = _textura_luz()
	_luz.texture_scale = 1.2
	_luz.color = Color(0.85, 0.9, 1.0)
	_luz.energy = 0.15
	_luz.position = Vector2(0, -30)
	add_child(_luz)

	_chamuco = Sprite2D.new()
	_chamuco.texture = CHAMUCO
	_chamuco.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_chamuco.centered = false
	_chamuco.region_enabled = true
	add_child(_chamuco)
	_poner_salida(0.0)

	_grieta = Sprite2D.new()
	_grieta.texture = GRIETA
	_grieta.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_grieta.position = Vector2(0, 4)
	add_child(_grieta)

	_polvo = CPUParticles2D.new()
	_polvo.amount = 18
	_polvo.lifetime = 0.8
	_polvo.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_polvo.emission_rect_extents = Vector2(55, 2)
	_polvo.direction = Vector2.UP
	_polvo.spread = 25.0
	_polvo.gravity = Vector2(0, 120)
	_polvo.initial_velocity_min = 40.0
	_polvo.initial_velocity_max = 110.0
	_polvo.scale_amount_min = 1.5
	_polvo.scale_amount_max = 3.0
	_polvo.color = Color(0.6, 0.6, 0.6, 0.8)
	_polvo.emitting = false
	add_child(_polvo)

	_area = Area2D.new()
	var forma := RectangleShape2D.new()
	forma.size = Vector2(54, 150)
	var cs := CollisionShape2D.new()
	cs.shape = forma
	cs.position = Vector2(0, -75)
	_area.add_child(cs)
	add_child(_area)


func _textura_luz() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


## Muestra solo la parte del chamuco que ya salió del suelo
func _poner_salida(f: float) -> void:
	_salida = clampf(f, 0.0, 1.0)
	var tam := CHAMUCO.get_size()
	var visible_alto := tam.y * _salida
	_chamuco.visible = visible_alto > 1.0
	_chamuco.region_rect = Rect2(0, 0, tam.x, maxf(visible_alto, 1.0))
	_chamuco.position = Vector2(-tam.x * 0.5, -visible_alto + 4.0)


func _activa() -> bool:
	var nivel := get_tree().get_first_node_in_group("nivel")
	if nivel == null:
		return true
	if nivel.has_method("amenazas_activas") and not nivel.amenazas_activas():
		return false
	if nivel.has_method("misma_pantalla") and not nivel.misma_pantalla(global_position):
		return false
	return true


func _process(delta: float) -> void:
	if not _activa():
		if estado != "calma":
			_esconder()
		return
	_t -= delta
	match estado:
		"calma":
			_luz.energy = lerpf(_luz.energy, 0.15, 1.0 - exp(-5.0 * delta))
			if _t <= 0.0:
				estado = "aviso"
				_t = aviso
				_polvo.emitting = true
				Juego.sfx("grunido", -8.0, randf_range(1.2, 1.4))
		"aviso":
			# La grieta brilla cada vez más y tiembla
			var f := 1.0 - _t / aviso
			_luz.energy = 0.3 + f * 1.4 + 0.2 * sin(_t * 40.0)
			_grieta.position.x = randf_range(-1.5, 1.5)
			if _t <= 0.0:
				estado = "afuera"
				_t = afuera
				_grieta.position.x = 0.0
				Juego.sfx("susto_suave", -12.0, 1.3)
		"afuera":
			_poner_salida(_salida + delta * 9.0)
			_luz.energy = 1.0
			_revisar_golpe()
			if _t <= 0.0:
				estado = "bajando"
				_polvo.emitting = false
		"bajando":
			_poner_salida(_salida - delta * 4.0)
			if _salida <= 0.0:
				estado = "calma"
				_t = randf_range(calma_min, calma_max)


func _revisar_golpe() -> void:
	if _salida < 0.5:
		return
	for b in _area.get_overlapping_bodies():
		if b.is_in_group("jugador") and not b.atrapada:
			Juego.susto("chamuco")
			b.ser_atrapada("¡Un chamuco salió de la grieta!")
			return


func _esconder() -> void:
	estado = "calma"
	_t = randf_range(calma_min, calma_max) + desfase
	_polvo.emitting = false
	_grieta.position.x = 0.0
	_poner_salida(0.0)
	_luz.energy = 0.15


func peligrosa() -> bool:
	return estado == "aviso" or estado == "afuera"
