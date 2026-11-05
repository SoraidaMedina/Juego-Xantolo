extends Node2D
## Escena final — El Pueblo
## Xochik llega de noche, lleva la ofrenda al altar, las ánimas regresan,
## amanece y salen los créditos.
## Necesita: Fondo, Suelo, Xochik (con Camera2D) y una Meta (meta.tscn) sobre el altar
## con "Es Entrada" DESACTIVADO.

@export_file("*.tscn") var escena_inicio: String = ""   # para "volver a jugar" (Nivel1Sierra)
## Imágenes que aparecen en el altar, en orden
@export var objetos_ofrenda: PackedStringArray = [
	"res://assets/objetos/vela1.png",
	"res://assets/objetos/flor_cempasuchil.png",
	"res://assets/objetos/pan_de_muerto.png",
	"res://assets/objetos/trompo.png",
	"res://assets/objetos/petalos.png",
	"res://assets/objetos/copal.png",
	"res://assets/objetos/vela2.png",
]
@export var escala_objetos: float = 0.14
## Ancho del altar donde se acomodan los objetos (px)
@export var ancho_altar: float = 180.0
## Subir/bajar los objetos (solo si NO usas un Marker2D llamado "Altar")
@export var altura_objetos: float = -20.0
@export_range(0.0, 1.0) var oscuridad: float = 0.4
@export_multiline var creditos: String = "Xantolo: El Camino de las Ánimas\n\nGuadalupe Mishel Hernández Govea\nSoraida Medina Bautista\nLuis Gustavo Hernández Hernández\n\nNU-B Studio"

var _jugador: Node
var _oscuro: CanvasModulate
var _capa: CanvasLayer
var _negro: ColorRect
var _mensaje: Label
var _ayuda: Label
var _creditos: Label
var _fin := false


func _ready() -> void:
	_asegurar_accion("interactuar", KEY_E)
	_jugador = get_tree().get_first_node_in_group("jugador")
	_configurar_camara()

	_oscuro = CanvasModulate.new()
	_oscuro.color = Color(oscuridad, oscuridad, oscuridad * 1.1)
	add_child(_oscuro)
	_crear_ui()

	var meta = get_tree().get_first_node_in_group("meta")
	if meta:
		meta.alcanzada.connect(_ritual.bind(meta))

	# Llega desde la cueva: aparece desde negro
	var tw := create_tween()
	tw.tween_property(_negro, "color:a", 0.0, 2.0)
	await tw.finished
	await _decir("El pueblo… las velas siguen encendidas.", 3.0)
	_ayuda.visible = true


func _process(_delta: float) -> void:
	if _fin and Input.is_action_just_pressed("interactuar") and escena_inicio != "":
		get_tree().change_scene_to_file(escena_inicio)


# ---------- El ritual ----------

func _ritual(meta: Node2D) -> void:
	_ayuda.visible = false
	if _jugador:
		_jugador.atrapada = true
		_jugador.velocity = Vector2.ZERO
		_jugador.get_node("AnimatedSprite2D").play("idle")

	await _decir("Xochik coloca la ofrenda en el altar…", 2.5)

	# Aparecen los objetos uno por uno sobre el altar
	var lista: Array = []
	for ruta in objetos_ofrenda:
		if ResourceLoader.exists(ruta):
			lista.append(load(ruta))
	for i in lista.size():
		var s := Sprite2D.new()
		s.texture = lista[i]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2.ONE * escala_objetos
		var x := 0.0 if lista.size() == 1 else lerpf(-ancho_altar / 2.0, ancho_altar / 2.0, float(i) / (lista.size() - 1))
		s.global_position = _punto_altar(meta) + Vector2(x, 12.0)
		s.modulate = Color(1, 0.9, 0.7, 0.0)
		add_child(s)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(s, "modulate:a", 1.0, 0.5)
		tw.tween_property(s, "global_position:y", s.global_position.y - 12.0, 0.5)
		await get_tree().create_timer(0.55).timeout

	# Luz cálida del altar
	var luz := _crear_luz(_punto_altar(meta) + Vector2(0, -20))
	create_tween().tween_property(luz, "energy", 1.2, 2.0)

	# Bajan las ánimas
	_animas(_punto_altar(meta))
	await _decir("Las ánimas encuentran el camino de regreso a casa…", 4.0)

	# Amanece
	var amanecer := create_tween()
	amanecer.tween_property(_oscuro, "color", Color(1.0, 0.93, 0.86), 6.0)
	await _decir("El Xantolo se ha restaurado.\nVivos y muertos vuelven a estar juntos.", 5.0)
	await amanecer.finished

	_mostrar_creditos()


## Si existe un Marker2D llamado "Altar", los objetos se acomodan ahí (centro de la mesa)
func _punto_altar(meta: Node2D) -> Vector2:
	var m := get_node_or_null("Altar") as Node2D
	if m:
		return m.global_position
	return meta.global_position + Vector2(0, altura_objetos)


func _animas(centro: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.global_position = centro + Vector2(0, -320)
	p.amount = 40
	p.lifetime = 5.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(260, 20)
	p.direction = Vector2.DOWN
	p.spread = 25.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 50.0
	p.gravity = Vector2(0, 8)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.6, 0.0))
	g.add_point(0.2, Color(1.0, 0.85, 0.55, 0.9))
	g.set_color(g.get_point_count() - 1, Color(1.0, 0.8, 0.5, 0.0))
	p.color_ramp = g
	add_child(p)
	p.emitting = true


func _crear_luz(pos: Vector2) -> PointLight2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var l := PointLight2D.new()
	l.texture = tex
	l.texture_scale = 2.0
	l.color = Color(1.0, 0.8, 0.5)
	l.energy = 0.0
	l.global_position = pos
	add_child(l)
	return l


func _mostrar_creditos() -> void:
	var tw := create_tween()
	tw.tween_property(_negro, "color:a", 0.85, 2.0)
	await tw.finished
	_creditos.text = creditos
	_creditos.modulate.a = 0.0
	_creditos.visible = true
	create_tween().tween_property(_creditos, "modulate:a", 1.0, 2.0)
	await get_tree().create_timer(3.0).timeout
	if escena_inicio != "":
		_ayuda.text = "[E] Volver a jugar"
		_ayuda.visible = true
	_fin = true


# ---------- UI ----------

func _crear_ui() -> void:
	_capa = CanvasLayer.new()
	add_child(_capa)

	_negro = ColorRect.new()
	_negro.color = Color(0, 0, 0, 1)
	_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capa.add_child(_negro)

	_mensaje = _label(20)
	_mensaje.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mensaje.position.y = 60
	_mensaje.modulate = Color(1.0, 0.85, 0.55)
	_mensaje.visible = false
	_capa.add_child(_mensaje)

	_creditos = _label(22)
	_creditos.set_anchors_preset(Control.PRESET_CENTER)
	_creditos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_creditos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_creditos.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_creditos.grow_vertical = Control.GROW_DIRECTION_BOTH
	_creditos.visible = false
	_capa.add_child(_creditos)

	_ayuda = _label(14)
	_ayuda.text = "Lleva la ofrenda al altar →"
	_ayuda.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ayuda.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_ayuda.position.y = get_viewport().get_visible_rect().size.y - 40
	_ayuda.modulate = Color(1, 1, 1, 0.8)
	_ayuda.visible = false
	_capa.add_child(_ayuda)


func _label(tam: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l


func _decir(txt: String, seg: float) -> void:
	_mensaje.text = txt
	_mensaje.modulate.a = 0.0
	_mensaje.visible = true
	var a := create_tween()
	a.tween_property(_mensaje, "modulate:a", 1.0, 0.6)
	await get_tree().create_timer(seg).timeout
	var b := create_tween()
	b.tween_property(_mensaje, "modulate:a", 0.0, 0.6)
	await b.finished


# ---------- Cámara ----------

func _configurar_camara() -> void:
	if _jugador == null:
		return
	var camara := _jugador.get_node_or_null("Camera2D") as Camera2D
	if camara == null:
		return
	var fondo := get_node_or_null("Fondo") as Sprite2D
	if fondo and fondo.texture:
		var r := fondo.get_rect()
		var e1 := fondo.to_global(r.position)
		var e2 := fondo.to_global(r.end)
		camara.limit_left = int(minf(e1.x, e2.x))
		camara.limit_top = int(minf(e1.y, e2.y))
		camara.limit_right = int(maxf(e1.x, e2.x))
		camara.limit_bottom = int(maxf(e1.y, e2.y))


func _asegurar_accion(nombre: String, tecla: Key) -> void:
	if InputMap.has_action(nombre):
		return
	InputMap.add_action(nombre)
	var ev := InputEventKey.new()
	ev.physical_keycode = tecla
	InputMap.action_add_event(nombre, ev)
