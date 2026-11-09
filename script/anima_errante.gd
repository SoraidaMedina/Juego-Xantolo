extends Node2D
## Ánima perdida que vaga al fondo de la cueva (solo ambiente: no hace daño).
## Flota de un lado a otro, se desvanece y vuelve a aparecer; trae una luz fría y tenue.

@export var recorrido: float = 220.0
@export var velocidad: float = 0.25
@export var opacidad: float = 0.45

const CUADROS := [preload("res://assets/cueva/anima_perdida_1.png"), preload("res://assets/cueva/anima_perdida_2.png")]

var _spr: Sprite2D
var _luz: PointLight2D
var _origen: Vector2
var _t := 0.0


func _ready() -> void:
	_origen = position
	_t = randf() * TAU
	z_index = -5
	_spr = Sprite2D.new()
	_spr.texture = CUADROS[0]
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	_luz = PointLight2D.new()
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
	_luz.texture = tex
	_luz.texture_scale = 1.6
	_luz.color = Color(0.8, 0.88, 1.0)
	_luz.energy = 0.35
	add_child(_luz)


func _process(delta: float) -> void:
	_t += delta
	var x := sin(_t * velocidad) * recorrido * 0.5
	var y := sin(_t * velocidad * 3.1) * 10.0
	position = _origen + Vector2(x, y)
	_spr.flip_h = cos(_t * velocidad) < 0.0
	_spr.texture = CUADROS[int(_t * 3.0) % 2]
	# Aparece y desaparece como un mal recuerdo
	var a := clampf(0.5 + 0.8 * sin(_t * 0.45), 0.0, 1.0) * opacidad
	_spr.modulate.a = a
	_luz.energy = 0.35 * a / maxf(opacidad, 0.01)
