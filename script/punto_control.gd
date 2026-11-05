extends Area2D

var _activado := false

func _ready() -> void:
	body_entered.connect(_al_entrar)

func _al_entrar(cuerpo: Node2D) -> void:
	if _activado or not cuerpo.is_in_group("jugador"):
		return
	_activado = true
	cuerpo.set("punto_reaparicion", global_position)
	_mostrar_aviso()

func _mostrar_aviso() -> void:
	var aviso := Label.new()
	aviso.text = "Punto de control"
	aviso.position = Vector2(-60, -70)
	aviso.add_theme_font_size_override("font_size", 12)
	aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	aviso.add_theme_constant_override("outline_size", 4)
	aviso.modulate = Color(1.0, 0.85, 0.55)
	add_child(aviso)
	var tw := create_tween()
	tw.tween_property(aviso, "position:y", -95.0, 1.5)
	tw.parallel().tween_property(aviso, "modulate:a", 0.0, 1.5)
	tw.tween_callback(aviso.queue_free)
