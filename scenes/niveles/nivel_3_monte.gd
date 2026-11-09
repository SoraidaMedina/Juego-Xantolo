extends Node2D
## Nivel 3 — El Monte del Nahual
## Objetivo: cruzar el monte hasta el pueblo sin que el Nahual te cace.
## Cuando el Nahual vigila: quédate QUIETA y OCULTA LA LUZ [F]. La luz se gasta mientras brilla.

@export var ancho_nivel: int = 1152
@export var alto_nivel: int = 648
@export_file("*.tscn") var siguiente_nivel: String = ""
## Qué tan oscuro es el monte (0 = negro, 1 = normal)
@export_range(0.0, 1.0) var oscuridad: float = 0.28
## Luz de Chicomexochitl
@export var luz_max: float = 100.0
@export var gasto_luz: float = 3.0          # por segundo mientras brilla
@export var recuperacion_luz: float = 7.0   # por segundo mientras está oculta
@export var radio_luz: float = 1.6
## Diálogo de la abuela (o mensajes en pantalla si no hay abuela)
@export var mensajes_tutorial: PackedStringArray = [
	"Este es el Monte del Nahual, mija. Detrás de estos cerros ya está el pueblo.",
	"El Nahual no ve bien en la oscuridad… pero siente cuando algo se mueve, y la luz lo atrae.",
	"Cuando se detenga a vigilar, quédate quieta… y oculta la luz de Chicomexochitl con [F].",
	"Esa luz se gasta mientras brilla y regresa cuando la ocultas. No la desperdicies.",
	"Si viene hacia ti, no corras, mija: quieta y con la luz oculta… pasará de largo.",
	"Si encuentras arbustos, agáchate [%agachar%] entre ellos. Ahí no te puede ver.",
	"Más abajo las ánimas perdidas dejaron una trampa: manos que salen de la niebla. Séllala con papel picado [E].",
	"Te guardé un puñado de pétalos de cempasúchil. Espárcelos [V]: marcan el camino… y descubren lo que está escondido.",
	"Tu abuelo escondió su amuleto bordado por aquí. Úsalo [C] y por un momento el Nahual no podrá sentirte.",
	"Sube por las rocas hasta el hueco de la montaña. Por dentro de la cueva se llega al pueblo.",
	"Llega antes del amanecer, mija. Tu familia te espera.",
]
@export var segundos_por_mensaje: float = 4.5
## Pétalos de cempasúchil: al esparcirlos [V] marcan el tramo de camino que sigue y revelan lo oculto
@export var petalos_iniciales: int = 3
@export var petalos_por_tramo: int = 7
@export var duracion_petalos: float = 12.0
@export var radio_revelar: float = 360.0
## Camino correcto hasta la cueva, en orden (sobre las rocas y el suelo)
@export var camino_petalos: PackedVector2Array = [
	Vector2(1200, 385), Vector2(1192, 522), Vector2(1109, 555), Vector2(1042, 590),
	Vector2(963, 642), Vector2(880, 666), Vector2(790, 666), Vector2(700, 666),
	Vector2(610, 666), Vector2(520, 666), Vector2(430, 666), Vector2(351, 637),
	Vector2(252, 590), Vector2(136, 550), Vector2(160, 496), Vector2(269, 458),
	Vector2(225, 405), Vector2(194, 362),
]

var luz: float
var _luz_oculta := false
var _luz_agotada := false
var _luz: PointLight2D
var _oscuro: CanvasModulate
var _tex_luz: GradientTexture2D

var _jugador: Node
var _hud  # script/hud.gd
const HUD := preload("res://script/hud.gd")
const PETALO := preload("res://assets/hud/ofrenda_petalos.png")
var _mensaje: Label
var _terminado := false
var _vigilando := 0
var _aviso_mostrado := false
var _jugando := false   # empieza cuando termina el diálogo
var _aviso_cerca := false


func _ready() -> void:
	add_to_group("nivel")
	_asegurar_accion("interactuar", KEY_E)
	_asegurar_accion("ocultar_luz", KEY_F)
	_asegurar_accion("esparcir_petalos", KEY_V)
	luz = luz_max
	_jugador = get_tree().get_first_node_in_group("jugador")
	_configurar_camara()
	_crear_oscuridad_y_luz()
	_crear_hud()
	if _jugador:
		_hud.preparar(_jugador)
		_jugador.petalos = petalos_iniciales
		_jugador.sin_vidas.connect(_game_over)
	for n in get_tree().get_nodes_in_group("nahual"):
		n.vigilancia.connect(_on_vigilancia)
	var meta = get_tree().get_first_node_in_group("meta")
	if meta:
		meta.alcanzada.connect(_victoria)
	for obj in get_tree().get_nodes_in_group("recolectable"):
		obj.recogido.connect(_al_recoger)
	_tutorial()


func _al_recoger(obj: Node) -> void:
	if _jugador == null:
		return
	match obj.tipo:
		"papel_picado":
			_jugador.papel_picado += 1
			_mostrar_mensaje("Papel picado: sella la trampa de las ánimas  [E]", 3.0)
		"amuleto":
			_jugador.amuletos += 2
			_mostrar_mensaje("Amuleto bordado (2 usos): el Nahual no te sentirá por un momento  [C]", 3.5)
	_actualizar_hud()


## La consulta el Nahual: ¿se ve la luz de Xochik?
func luz_visible() -> bool:
	return not _luz_oculta and not _luz_agotada


func _process(delta: float) -> void:
	if _terminado or not _jugando:
		return
	var quiere_ocultar := Input.is_action_pressed("ocultar_luz")
	_luz_oculta = quiere_ocultar

	if luz_visible():
		luz = maxf(luz - gasto_luz * delta, 0.0)
		if luz <= 0.0:
			_luz_agotada = true
			_mostrar_mensaje("La luz se agotó… ocúltala para que se recupere", 2.5)
	else:
		luz = minf(luz + recuperacion_luz * delta, luz_max)
		if _luz_agotada and luz >= luz_max * 0.3:
			_luz_agotada = false

	_revisar_cercania()
	if _luz:
		var energia := 0.12 if not luz_visible() else lerpf(0.5, 1.15, luz / luz_max)
		_luz.energy = lerpf(_luz.energy, energia, 1.0 - exp(-10.0 * delta))
	_actualizar_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("esparcir_petalos"):
		_esparcir_petalos()


# ---------- Pétalos de cempasúchil ----------

## Los pétalos vuelan y se posan, brillando, sobre el tramo de camino que sigue hacia la cueva.
## Lo que las ánimas escondieron cerca (el amuleto) aparece.
func _esparcir_petalos() -> void:
	if not _jugando or _terminado or _jugador == null or _jugador.atrapada:
		return
	if _jugador.petalos <= 0:
		_mostrar_mensaje("Ya no te quedan pétalos…", 1.5)
		return
	_jugador.petalos -= 1
	_hud.usar("petalos")
	Juego.sfx("recoger", -6.0, 1.4)
	var desde: Vector2 = _jugador.global_position
	for n in get_tree().get_nodes_in_group("oculto_petalos"):
		if n is Node2D and (n as Node2D).global_position.distance_to(desde) <= radio_revelar:
			n.revelar()
			_mostrar_mensaje("Los pétalos descubrieron algo escondido…", 2.5)
	if camino_petalos.is_empty():
		return
	var cerca := 0
	var mejor := INF
	for i in camino_petalos.size():
		var d: float = camino_petalos[i].distance_to(desde)
		if d < mejor:
			mejor = d
			cerca = i
	var fin := mini(cerca + petalos_por_tramo, camino_petalos.size())
	var k := 0
	for i in range(cerca, fin):
		_soltar_petalo(desde + Vector2(0, -30), camino_petalos[i], k * 0.15)
		k += 1


func _soltar_petalo(desde: Vector2, hacia: Vector2, retraso: float) -> void:
	var p := Node2D.new()
	p.modulate.a = 0.0
	add_child(p)
	p.global_position = desde
	var spr := Sprite2D.new()
	spr.texture = PETALO
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(2, 2)
	spr.position = Vector2(0, -10)
	p.add_child(spr)
	var luz_p := PointLight2D.new()
	luz_p.texture = _tex_luz
	luz_p.texture_scale = 0.4
	luz_p.color = Color(1.0, 0.85, 0.6)
	luz_p.energy = 0.0
	p.add_child(luz_p)
	var medio := (desde + hacia) * 0.5 + Vector2(0, -80)
	var tw := p.create_tween()
	tw.tween_interval(retraso)
	tw.tween_property(p, "modulate:a", 1.0, 0.1)
	tw.tween_method(_mover_petalo.bind(p, desde, medio, hacia), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(spr, "rotation", randf_range(-0.6, 0.6), 0.7)
	tw.parallel().tween_property(luz_p, "energy", 0.9, 0.7)
	tw.tween_property(luz_p, "energy", 0.55, 0.6)
	tw.tween_interval(duracion_petalos)
	tw.tween_property(p, "modulate:a", 0.0, 1.5)
	tw.parallel().tween_property(luz_p, "energy", 0.0, 1.5)
	tw.tween_callback(p.queue_free)


func _mover_petalo(t: float, nodo: Node2D, a: Vector2, b: Vector2, c: Vector2) -> void:
	nodo.global_position = a.lerp(b, t).lerp(b.lerp(c, t), t)


## La primera vez que el Nahual se acerca, recuerda cómo dejarlo pasar
func _revisar_cercania() -> void:
	if _aviso_cerca or _jugador == null:
		return
	for n in get_tree().get_nodes_in_group("nahual"):
		if n.global_position.distance_to(_jugador.global_position) < 260.0 and not _jugador.esta_escondida():
			_aviso_cerca = true
			_mostrar_mensaje("Se acerca… quédate quieta y oculta la luz  [F]", 3.0)


func _on_vigilancia(activa: bool) -> void:
	_vigilando += 1 if activa else -1
	_vigilando = maxi(_vigilando, 0)
	_hud.alerta("EL NAHUAL VIGILA", _vigilando > 0)
	if activa and not _aviso_mostrado:
		_aviso_mostrado = true
		Juego.susto_ambiente("nahual")
		_mostrar_mensaje(_teclas("¡Te busca! Quédate quieta y oculta la luz [F]"), 2.5)


# ---------- Oscuridad + luz de Chicomexochitl ----------

func _crear_oscuridad_y_luz() -> void:
	_oscuro = CanvasModulate.new()
	_oscuro.color = Color.WHITE   # se oscurece cuando termina el diálogo
	add_child(_oscuro)

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
	_tex_luz = tex

	_luz = PointLight2D.new()
	_luz.texture = tex
	_luz.texture_scale = radio_luz
	_luz.color = Color(1.0, 0.85, 0.6)   # cálida, como vela
	_luz.energy = 1.1
	var portador := _buscar_chicomexochitl()
	if portador == null:
		portador = _jugador
	if portador:
		portador.add_child(_luz)


func _buscar_chicomexochitl() -> Node:
	for n in get_children():
		var s = n.get_script()
		if s and String(s.resource_path).to_lower().contains("chicomexochitl"):
			return n
	return null


# ---------- Final ----------

func _victoria() -> void:
	_terminado = true
	_hud.alerta("", false)
	# Fundido a negro: cruza el monte por dentro de la cueva
	var negro := ColorRect.new()
	negro.color = Color(0, 0, 0, 0)
	negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mensaje.get_parent().add_child(negro)
	_mensaje.get_parent().move_child(negro, 0)
	var a := create_tween()
	a.tween_property(negro, "color:a", 1.0, 1.2)
	await a.finished
	_mostrar_mensaje("Xochik cruzó el monte por dentro de la cueva…", 0.0)
	await get_tree().create_timer(3.0, false).timeout
	# Del otro lado: amanece
	if _luz:
		_luz.energy = 0.0
	_oscuro.color = Color(0.35, 0.33, 0.36)
	_mostrar_mensaje("Llegaste al pueblo…\nEl sol del Xantolo comienza a salir", 0.0)
	var b := create_tween().set_parallel(true)
	b.tween_property(negro, "color:a", 0.0, 2.5)
	b.tween_property(_oscuro, "color", Color(1.0, 0.92, 0.85), 4.0)
	await get_tree().create_timer(5.0, false).timeout
	Juego.ir_a(siguiente_nivel)  # vacío = siguiente nivel de la lista


func _game_over() -> void:
	_terminado = true
	await get_tree().create_timer(1.0, false).timeout
	Juego.game_over("El Nahual te encontró…")


# ---------- Tutorial ----------

func _tutorial() -> void:
	var abuela = get_tree().get_first_node_in_group("abuela")
	if abuela:
		var lista := PackedStringArray()
		for m in mensajes_tutorial:
			lista.append(_teclas(m))
		await get_tree().process_frame
		await abuela.decir(lista)
	else:
		await get_tree().create_timer(0.5, false).timeout
		for m in mensajes_tutorial:
			if _terminado:
				return
			_mostrar_mensaje(_teclas(m), segundos_por_mensaje)
			await get_tree().create_timer(segundos_por_mensaje + 1.2, false).timeout
	_caer_la_noche()


## Cuando termina el diálogo, el monte se oscurece y empieza el sigilo
func _caer_la_noche() -> void:
	var tw := create_tween()
	tw.tween_property(_oscuro, "color", Color(oscuridad, oscuridad, oscuridad * 1.1), 2.0)
	await tw.finished
	_jugando = true


# ---------- Cámara ----------

func _configurar_camara() -> void:
	if _jugador == null:
		return
	var camara := _jugador.get_node_or_null("Camera2D") as Camera2D
	if camara == null:
		return
	camara.zoom = Vector2.ONE
	var fondo := get_node_or_null("Fondo") as Sprite2D
	if fondo and fondo.texture:
		var r := fondo.get_rect()
		var esq1 := fondo.to_global(r.position)
		var esq2 := fondo.to_global(r.end)
		camara.limit_left = int(minf(esq1.x, esq2.x))
		camara.limit_top = int(minf(esq1.y, esq2.y))
		camara.limit_right = int(maxf(esq1.x, esq2.x))
		camara.limit_bottom = int(maxf(esq1.y, esq2.y))
	else:
		camara.limit_left = 0
		camara.limit_top = 0
		camara.limit_right = ancho_nivel
		camara.limit_bottom = alto_nivel


# ---------- HUD ----------

func _crear_hud() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)

	_hud = HUD.new()
	capa.add_child(_hud)
	_hud.agregar_ofrenda_del_viaje(true)
	_hud.mostrar_luz()
	_hud.agregar_talisman("papel_picado", "interactuar", 0)
	_hud.agregar_talisman("amuleto", "amuleto", 0)
	_hud.agregar_talisman("petalos", "esparcir_petalos", petalos_iniciales)
	_hud.ayuda([
		[["izquierda", "derecha"], "Moverse"],
		[["saltar"], "Saltar"],
		[["agachar"], "Agacharse"],
		[["ocultar_luz"], "Ocultar luz (mantener)"],
	])

	_mensaje = _label_base(20)
	_mensaje.set_anchors_preset(Control.PRESET_CENTER)
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mensaje.grow_vertical = Control.GROW_DIRECTION_BOTH
	_mensaje.modulate = Color(0.95, 0.95, 0.95)
	_mensaje.visible = false
	capa.add_child(_mensaje)
	_actualizar_hud()


func _label_base(tam: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l


func _actualizar_hud() -> void:
	if _hud == null:
		return
	_hud.luz(luz, luz_max, _luz_agotada, _luz_oculta)


func _mostrar_mensaje(txt: String, duracion: float) -> void:
	_mensaje.text = txt
	_mensaje.modulate.a = 1.0
	_mensaje.visible = true
	if duracion > 0.0:
		await get_tree().create_timer(duracion, false).timeout
		if not _terminado:
			var tw := create_tween()
			tw.tween_property(_mensaje, "modulate:a", 0.0, 1.0)


func _teclas(txt: String) -> String:
	for accion in ["izquierda", "derecha", "saltar", "agachar"]:
		var tecla: String = accion
		if InputMap.has_action(accion):
			var nombres: Array[String] = []
			for ev in InputMap.action_get_events(accion):
				if ev is InputEventKey:
					var n: String = ev.as_text().replace(" (Physical)", "").replace(" - Physical", "")
					n = n.replace("Down", "↓").replace("Up", "↑").replace("Left", "←").replace("Right", "→")
					if not nombres.has(n):
						nombres.append(n)
			if not nombres.is_empty():
				tecla = " / ".join(nombres)
		txt = txt.replace("%" + accion + "%", tecla)
	return txt


func _asegurar_accion(nombre: String, tecla: Key) -> void:
	if InputMap.has_action(nombre):
		return
	InputMap.add_action(nombre)
	var ev := InputEventKey.new()
	ev.physical_keycode = tecla
	InputMap.action_add_event(nombre, ev)
