extends Area2D
## Trampa espiritual: niebla fría con manos de ánimas que salen del suelo.
## Si Xochik la cruza, las manos la jalan (pierde una vida y retrocede).
## Se SELLA con papel picado: acércate y pulsa [E] (se gasta un papel picado).
## Pon el nodo con su base en el piso (position.y = y del suelo).

@export var ancho: float = 96.0
@export var alto: float = 150.0

var activa := true
var _manos: Sprite2D
var _niebla: CPUParticles2D
var _aviso: Label
var _t := 0.0


func _ready() -> void:
	add_to_group("trampas")
	var forma := RectangleShape2D.new()
	forma.size = Vector2(ancho * 0.7, alto)
	var cs := CollisionShape2D.new()
	cs.shape = forma
	cs.position = Vector2(0, -alto / 2.0)
	add_child(cs)
	body_entered.connect(_al_entrar)

	_niebla = CPUParticles2D.new()
	_niebla.amount = 40
	_niebla.lifetime = 2.2
	_niebla.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_niebla.emission_rect_extents = Vector2(ancho / 2.0, 6)
	_niebla.direction = Vector2.UP
	_niebla.spread = 15.0
	_niebla.initial_velocity_min = 20.0
	_niebla.initial_velocity_max = 50.0
	_niebla.gravity = Vector2.ZERO
	_niebla.scale_amount_min = 6.0
	_niebla.scale_amount_max = 14.0
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.9, 0.9, 0.35))
	g.set_color(1, Color(0.7, 0.7, 0.7, 0.0))
	_niebla.color_ramp = g
	add_child(_niebla)

	_manos = Sprite2D.new()
	_manos.texture = load("res://assets/talismanes/manos_animas.png")
	_manos.hframes = 2
	_manos.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_manos.position = Vector2(0, -_manos.texture.get_height() / 2.0)
	_manos.modulate = Color(1, 1, 1, 0.85)
	add_child(_manos)

	_aviso = Label.new()
	_aviso.add_theme_font_size_override("font_size", 14)
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 5)
	_aviso.position = Vector2(-110, -alto - 40)
	_aviso.visible = false
	add_child(_aviso)


func _process(delta: float) -> void:
	_t += delta
	if not activa:
		return
	# Las manos se abren y se cierran, y suben y bajan
	_manos.frame = int(_t * 2.5) % 2
	_manos.position.y = -_manos.texture.get_height() / 2.0 + sin(_t * 2.0) * 6.0
	var j := get_tree().get_first_node_in_group("jugador") as CharacterBody2D
	if j == null:
		return
	var cerca := absf(j.global_position.x - global_position.x) < ancho + 90.0 \
		and absf(j.global_position.y - (global_position.y - alto / 2.0)) < 140.0
	_aviso.visible = cerca
	if not cerca:
		return
	var papeles: int = j.get("papel_picado") if j.get("papel_picado") != null else 0
	if papeles > 0:
		_aviso.text = "[E] Sellar con papel picado (x%d)" % papeles
		if Input.is_action_just_pressed("interactuar"):
			sellar(j)
	else:
		_aviso.text = "Necesitas papel picado para sellarla"


func _al_entrar(b: Node) -> void:
	if not activa or not b.is_in_group("jugador") or b.atrapada:
		return
	Juego.sfx("susto_suave", -2.0)
	b.ser_atrapada("Las manos de las ánimas te jalaron")
	# La avientan hacia atrás
	var lado := signf(b.global_position.x - global_position.x)
	if lado == 0.0:
		lado = 1.0
	b.global_position.x = global_position.x + lado * (ancho * 0.5 + 60.0)


func sellar(j: Node) -> void:
	activa = false
	j.papel_picado -= 1
	_aviso.visible = false
	set_deferred("monitoring", false)
	Juego.sfx("vela", -2.0, 0.8)
	Juego.sfx("recoger", -6.0, 0.7)
	_niebla.emitting = false
	# El papel picado queda pegado sobre la trampa
	var papel := Sprite2D.new()
	papel.texture = load("res://assets/objetos/papel_picado.png")
	papel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var h := float(papel.texture.get_height())
	papel.scale = Vector2.ONE * (70.0 / maxf(h, 1.0))
	papel.position = Vector2(0, -alto * 0.55)
	papel.modulate.a = 0.0
	add_child(papel)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(papel, "modulate:a", 1.0, 0.6)
	tw.tween_property(_manos, "modulate:a", 0.0, 1.2)
	tw.tween_property(_manos, "position:y", _manos.position.y + 40.0, 1.2)
