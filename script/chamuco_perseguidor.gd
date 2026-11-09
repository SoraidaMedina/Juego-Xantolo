extends Node2D
## El chamuco grande de la cueva. Duerme hasta que el nivel lo despierta (al tomar la foto del abuelo);
## entonces sale del suelo gritando y persigue a Xochik. Si la alcanza, pierde una vida y él
## vuelve a salir por la izquierda. La luz de la vela del abuelo lo deshace.
## Pon el nodo sobre el piso (position.y = y del suelo), a la izquierda de donde empieza la persecución.

@export var velocidad: float = 85.0
@export var espera_al_despertar: float = 1.6
@export var espera_al_atrapar: float = 2.5
@export var escala: float = 1.15

const PASO_1 := preload("res://assets/cueva/chamuco_1.png")
const PASO_2 := preload("res://assets/cueva/chamuco_2.png")
const GRITO := preload("res://assets/cueva/chamuco_grito.png")

var estado := "dormido"
var _inicio: Vector2
var _spr: Sprite2D
var _ojos: PointLight2D
var _t := 0.0
var _t_paso := 0.0


func _ready() -> void:
	add_to_group("perseguidor")
	_inicio = global_position
	_spr = Sprite2D.new()
	_spr.texture = PASO_1
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2.ONE * escala
	_spr.offset = Vector2(0, -PASO_1.get_height() * 0.5)
	add_child(_spr)
	# Una luz fría en la cara: en la oscuridad solo se le ven los ojos acercándose
	_ojos = PointLight2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_ojos.texture = tex
	_ojos.texture_scale = 1.4
	_ojos.color = Color(0.85, 0.9, 1.0)
	_ojos.energy = 0.0
	_ojos.position = Vector2(14, -150) * escala / 1.15
	add_child(_ojos)
	visible = false
	var j := get_tree().get_first_node_in_group("jugador")
	if j and j.has_signal("vidas_cambiadas"):
		j.vidas_cambiadas.connect(_al_perder_vida)


## Si Xochik pierde una vida por cualquier cosa (abismo, grieta), el chamuco vuelve a empezar
## desde su lugar: así nunca queda atrapada entre él y la vela.
func _al_perder_vida(_vidas: int) -> void:
	if estado != "persigue" and estado != "saliendo":
		return
	estado = "espera"
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	await tw.finished
	visible = false
	await get_tree().create_timer(espera_al_atrapar, false).timeout
	if estado == "espera":
		_salir()


func despertar() -> void:
	if estado != "dormido":
		return
	await _salir()


func _salir() -> void:
	estado = "saliendo"
	global_position = _inicio
	visible = true
	modulate.a = 1.0
	_spr.texture = GRITO
	_spr.scale = Vector2(escala, 0.05)
	Juego.sfx("grunido", -2.0, 0.7)
	Juego.susto_ambiente("chamuco")
	var tw := create_tween()
	tw.tween_property(_spr, "scale", Vector2.ONE * escala, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_ojos, "energy", 1.6, 0.6)
	await get_tree().create_timer(espera_al_despertar, false).timeout
	if estado == "saliendo":
		estado = "persigue"


func desvanecer() -> void:
	if estado == "fin":
		return
	estado = "fin"
	if not visible:
		return
	_spr.texture = GRITO
	Juego.sfx("susto_suave", -6.0, 0.6)
	var p := CPUParticles2D.new()
	p.position = Vector2(0, -90)
	p.one_shot = true
	p.explosiveness = 0.7
	p.amount = 40
	p.lifetime = 1.4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(25, 80)
	p.direction = Vector2.UP
	p.spread = 40.0
	p.gravity = Vector2(0, -40)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 70.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.15, 0.15, 0.15, 0.9)
	add_child(p)
	p.emitting = true
	var tw := create_tween()
	tw.tween_property(_spr, "modulate:a", 0.0, 1.2)
	tw.parallel().tween_property(_ojos, "energy", 0.0, 1.2)
	tw.tween_interval(0.5)
	tw.tween_callback(hide)


func _process(delta: float) -> void:
	if estado != "persigue":
		return
	var nivel := get_tree().get_first_node_in_group("nivel")
	if nivel and nivel.has_method("amenazas_activas") and not nivel.amenazas_activas():
		return
	var j := get_tree().get_first_node_in_group("jugador") as Node2D
	if j == null:
		return
	_t += delta
	var dx := j.global_position.x - global_position.x
	var dir := signf(dx)
	global_position.x += dir * velocidad * delta
	_spr.flip_h = dir < 0.0
	_ojos.position.x = absf(_ojos.position.x) * (-1.0 if dir < 0.0 else 1.0)
	# Camina encorvado, a sacudidas
	_t_paso += delta
	if _t_paso >= 0.2:
		_t_paso = 0.0
		_spr.texture = PASO_2 if _spr.texture == PASO_1 else PASO_1
	_spr.position.y = -absf(sin(_t * 8.0)) * 4.0
	_ojos.energy = 1.4 + 0.3 * sin(_t * 6.0)
	if absf(dx) < 36.0 and absf(j.global_position.y - (global_position.y - 70.0)) < 110.0 and not j.atrapada:
		_atrapar(j)


func _atrapar(j: Node) -> void:
	estado = "espera"
	_spr.texture = GRITO
	Juego.susto("chamuco")
	j.ser_atrapada("¡El chamuco te alcanzó!")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	await tw.finished
	visible = false
	await get_tree().create_timer(espera_al_atrapar, false).timeout
	if estado == "espera":
		_salir()
