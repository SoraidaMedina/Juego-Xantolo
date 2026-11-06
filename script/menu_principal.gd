extends Control
## Menú principal — Xantolo: El Camino de las Ánimas
## Todo se construye por código; en escala de grises como pide el documento técnico.

@export var fondo: Texture2D = preload("res://assets/fondos/pueblo_amanecer_bg.png")
@export var vela: Texture2D = preload("res://assets/xicomexochitl/chicomexochitl_idle.png")
@export_multiline var creditos: String = "Guadalupe Mishel Hernández Govea\nSoraida Medina Bautista\nLuis Gustavo Hernández Hernández\n\nUniversidad Tecnológica de la Huasteca Hidalguense\nCreación de Videojuegos · 2026"

var _principal: VBoxContainer
var _panel_info: VBoxContainer
var _texto_info: Label
var _titulo_info: Label
var _tabla_controles: GridContainer
var _vela: TextureRect
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_crear_fondo()
	_crear_menu()
	_mostrar_principal()


func _process(delta: float) -> void:
	_t += delta
	# La vela flota y su luz parpadea como una flama débil
	if _vela:
		_vela.position.y = _vela.get_meta("y0", _vela.position.y) + sin(_t * 1.8) * 6.0
		var flama := 0.85 + 0.1 * sin(_t * 7.0) + 0.05 * sin(_t * 13.0)
		_vela.modulate = Color(flama, flama, flama)


func _crear_fondo() -> void:
	var negro := ColorRect.new()
	negro.color = Color.BLACK
	negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(negro)

	var img := TextureRect.new()
	img.texture = fondo
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	img.modulate = Color(0.35, 0.35, 0.35)
	add_child(img)

	# Viñeta: oscurece la izquierda, donde va el menú
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.85))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0.8, 0)
	var vineta := TextureRect.new()
	vineta.texture = tex
	vineta.set_anchors_preset(Control.PRESET_FULL_RECT)
	vineta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vineta.stretch_mode = TextureRect.STRETCH_SCALE
	vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vineta)


func _crear_menu() -> void:
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 80)
	margen.add_theme_constant_override("margin_top", 60)
	margen.add_theme_constant_override("margin_bottom", 40)
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margen)

	var columna := VBoxContainer.new()
	columna.alignment = BoxContainer.ALIGNMENT_CENTER
	columna.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	columna.add_theme_constant_override("separation", 4)
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_child(columna)

	var titulo := Juego.crear_titulo("XANTOLO", 64)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	columna.add_child(titulo)
	var sub := Juego.crear_texto("El Camino de las Ánimas", 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	columna.add_child(sub)
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 36)
	columna.add_child(sep)

	_principal = VBoxContainer.new()
	_principal.add_theme_constant_override("separation", 4)
	columna.add_child(_principal)
	_agregar_boton(_principal, "Comenzar", Juego.nuevo_juego)
	_agregar_boton(_principal, "Controles", _mostrar_controles)
	_agregar_boton(_principal, "Créditos", _mostrar_creditos)
	_agregar_boton(_principal, "Salir", get_tree().quit)
	_crear_panel_info(columna)

	# Chicomexochitl, la vela viviente, a la derecha
	_vela = TextureRect.new()
	_vela.texture = vela
	_vela.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vela.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_vela.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vela.custom_minimum_size = Vector2(220, 220)
	_vela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vela.size = Vector2(220, 220)
	_vela.position = Vector2(get_viewport_rect().size.x - 320, get_viewport_rect().size.y * 0.5 - 140)
	_vela.set_meta("y0", _vela.position.y)
	add_child(_vela)


func _crear_panel_info(columna: VBoxContainer) -> void:
	# Ocupa el mismo lugar que los botones, debajo del título
	_panel_info = VBoxContainer.new()
	_panel_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_info.add_theme_constant_override("separation", 14)
	columna.add_child(_panel_info)
	_titulo_info = Juego.crear_titulo("", 26)
	_titulo_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_panel_info.add_child(_titulo_info)
	_texto_info = Juego.crear_texto("", 16)
	_texto_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_texto_info.add_theme_constant_override("line_spacing", 4)
	_panel_info.add_child(_texto_info)
	_tabla_controles = _crear_tabla_controles()
	_panel_info.add_child(_tabla_controles)
	var volver := Juego.crear_boton("‹  Volver")
	volver.alignment = HORIZONTAL_ALIGNMENT_LEFT
	volver.pressed.connect(_mostrar_principal)
	_panel_info.add_child(volver)


func _agregar_boton(caja: Container, texto: String, accion: Callable) -> void:
	var b := Juego.crear_boton(texto)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(accion)
	caja.add_child(b)


func _mostrar_principal() -> void:
	_panel_info.visible = false
	_principal.visible = true
	_principal.get_child(0).grab_focus()


func _mostrar_info(titulo: String, texto: String, con_controles: bool = false) -> void:
	_titulo_info.text = titulo
	_texto_info.text = texto
	_tabla_controles.visible = con_controles
	_principal.visible = false
	_panel_info.visible = true
	_panel_info.get_child(_panel_info.get_child_count() - 1).grab_focus()


func _mostrar_controles() -> void:
	_mostrar_info("Controles", "No puedes pelear: escóndete, quédate quieta y cuida tu luz.", true)


func _mostrar_creditos() -> void:
	_mostrar_info("Créditos", creditos)


func _crear_tabla_controles() -> GridContainer:
	var tabla := GridContainer.new()
	tabla.columns = 2
	tabla.add_theme_constant_override("h_separation", 32)
	tabla.add_theme_constant_override("v_separation", 6)
	var filas := [
		["A / D   ·   ← →", "Moverse"],
		["Espacio", "Saltar"],
		["S   ·   ↓", "Agacharse / esconderse en arbustos"],
		["E", "Tomar objetos · avanzar diálogo"],
		["Q", "Quemar copal (dispersa chaneques)"],
		["R", "Lanzar piedrita (distrae chaneques)"],
		["F  (mantener)", "Ocultar la luz de la vela"],
		["Esc", "Pausa"],
	]
	for f in filas:
		var tecla := Juego.crear_texto(f[0], 16)
		tecla.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		tecla.add_theme_color_override("font_color", Color.WHITE)
		tabla.add_child(tecla)
		var que := Juego.crear_texto(f[1], 16)
		que.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		que.modulate = Color(0.8, 0.8, 0.8)
		tabla.add_child(que)
	return tabla


func _unhandled_input(event: InputEvent) -> void:
	if _panel_info.visible and event.is_action_pressed("ui_cancel"):
		_mostrar_principal()
		get_viewport().set_input_as_handled()
