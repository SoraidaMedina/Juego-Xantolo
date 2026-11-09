extends CanvasLayer
## Recuerdos sin texto (como en Detention): imágenes en sombras que se funden una tras otra,
## con un leve acercamiento y parpadeo de vela. [E] adelanta la imagen.
## Uso:  var r := RECUERDOS.new();  add_child(r);  await r.mostrar([ruta1, ruta2, ruta3])

@export var segundos_por_imagen: float = 3.2

var _imagen: TextureRect
var _negro: ColorRect
var _saltar := false
var _t := 0.0


func _init() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_negro = ColorRect.new()
	_negro.color = Color(0, 0, 0, 0)
	_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_negro)
	_imagen = TextureRect.new()
	_imagen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_imagen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_imagen.modulate.a = 0.0
	add_child(_imagen)


func _process(delta: float) -> void:
	_t += delta
	if _imagen.modulate.a > 0.0:
		# Parpadeo de vela
		var f := 0.93 + 0.05 * sin(_t * 9.0) * sin(_t * 3.1)
		_imagen.self_modulate = Color(f, f, f)
	if Input.is_action_just_pressed("interactuar"):
		_saltar = true


func mostrar(rutas: Array) -> void:
	get_tree().paused = true
	Juego.bloquear_pausa = true
	var tw := create_tween()
	tw.tween_property(_negro, "color:a", 1.0, 0.8)
	await tw.finished
	Juego.sfx("vela", -4.0, 0.7)
	for ruta in rutas:
		if not ResourceLoader.exists(ruta):
			continue
		_imagen.texture = load(ruta)
		_imagen.pivot_offset = get_viewport().get_visible_rect().size * 0.5
		_imagen.scale = Vector2.ONE
		var entra := create_tween()
		entra.tween_property(_imagen, "modulate:a", 1.0, 0.7)
		var zoom := create_tween()
		zoom.tween_property(_imagen, "scale", Vector2(1.06, 1.06), segundos_por_imagen + 1.4)
		await entra.finished
		await _esperar(segundos_por_imagen)
		var sale := create_tween()
		sale.tween_property(_imagen, "modulate:a", 0.0, 0.7)
		await sale.finished
	var fin := create_tween()
	fin.tween_property(_negro, "color:a", 0.0, 0.8)
	await fin.finished
	Juego.bloquear_pausa = false
	get_tree().paused = false


func _esperar(seg: float) -> void:
	_saltar = false
	var t := 0.0
	while t < seg and not _saltar:
		await get_tree().process_frame
		t += get_process_delta_time()
