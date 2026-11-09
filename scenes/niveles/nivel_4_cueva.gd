extends Node2D
## Nivel 4 — La Cueva del Abuelo (2 pantallas de cámara fija, como Detention)
## Por dentro de la montaña, casi a oscuras. Tres objetos con memoria —el balero, la foto y la vela
## del abuelo— abren recuerdos sin texto que revelan por qué se rompió el ritual.
## Las corrientes de aire apagan la llama de Chicomexochitl: cuando silba el viento, agáchate [S].
## Con los tres recuerdos, la salida se ilumina con el amanecer y lleva al pueblo.

@export_file("*.tscn") var siguiente_nivel: String = ""
@export var ancho_pantalla: int = 1152
@export var alto_pantalla: int = 648
@export var nombres_pantallas: PackedStringArray = [
	"La boca de la cueva",
	"El corazón de la montaña",
]
## Qué tan oscura es la cueva (0 = negro, 1 = normal)
@export_range(0.0, 1.0) var oscuridad: float = 0.3
@export var radio_luz: float = 1.9
## Segundos que la llama tarda en volver a encenderse cuando el viento la apaga
@export var segundos_apagada: float = 3.5
@export var mensajes_intro: PackedStringArray = [
	"Por dentro de la montaña… aquí el viento corre entre las piedras.",
	"Cuando silbe, agáchate  [S]  y cúbreme con tu cuerpo. Si el viento me apaga, no verás dónde pisas.",
	"Siento a tu abuelo aquí dentro, Xochik. Hay cosas que guardan su memoria.",
]
## Lo que dice Chicomexochitl después de cada recuerdo
@export var despues_balero: PackedStringArray = [
	"Él te lo talló con sus manos… para el Xantolo del año pasado.",
]
@export var despues_foto: PackedStringArray = [
	"Se fue en la temporada de lluvias. Lo extrañas tanto…",
]
@export var despues_vela: PackedStringArray = [
	"Fuiste tú, Xochik… soplaste su vela.",
	"Sin esa luz tu abuelo no encontró el camino a casa… y las ánimas se perdieron con él.",
	"Todavía no amanece. Llévale su vela y su retrato. Vamos al pueblo  →",
]
@export var segundos_por_mensaje: float = 3.8

const RECUERDOS := preload("res://script/recuerdos.gd")
const HUD := preload("res://script/hud.gd")
const IMAGENES := {
	"balero": ["res://assets/cueva/recuerdo_1_a.png", "res://assets/cueva/recuerdo_1_b.png", "res://assets/cueva/recuerdo_1_c.png"],
	"foto": ["res://assets/cueva/recuerdo_2_a.png", "res://assets/cueva/recuerdo_2_b.png", "res://assets/cueva/recuerdo_2_c.png"],
	"vela": ["res://assets/cueva/recuerdo_3_a.png", "res://assets/cueva/recuerdo_3_b.png", "res://assets/cueva/recuerdo_3_c.png"],
}

var _hud  # script/hud.gd
var _jugador: CharacterBody2D
var _camara: Camera2D
var _chico: Node2D
var _luz: PointLight2D
var _luz_salida: PointLight2D
var _oscuro: CanvasModulate
var _lugar: Label
var _mensaje: Label
var _cortina: ColorRect
var _pantalla := -1
var _vistas := {}
var _jugando := false
var _recuerdos := {}
var _completado := false
var _saliendo := false
var _apagada := 0.0
var _tip_viento := false
var _tip_apagada := false
var _aviso_falta := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("nivel")
	_asegurar_accion("interactuar", KEY_E)
	_crear_hud()
	_jugador = get_tree().get_first_node_in_group("jugador") as CharacterBody2D
	if _jugador:
		_camara = _jugador.get_node_or_null("Camera2D") as Camera2D
		_hud.preparar(_jugador)
		_jugador.sin_vidas.connect(_game_over)
	for obj in get_tree().get_nodes_in_group("recolectable"):
		obj.recogido.connect(_al_recoger)
	_crear_oscuridad_y_luz()
	_revisar_pantalla(true)
	_intro()


func _intro() -> void:
	if _jugador:
		_jugador.atrapada = true
	await get_tree().create_timer(0.8, false).timeout
	for m in mensajes_intro:
		await _decir(m, segundos_por_mensaje)
	if _jugador:
		_jugador.atrapada = false
	_jugando = true


## Las corrientes de aire solo soplan mientras se juega (no durante diálogos ni recuerdos)
func corrientes_activas() -> bool:
	return _jugando


func _process(delta: float) -> void:
	_t += delta
	_revisar_pantalla(false)
	_revisar_luz(delta)
	_revisar_viento()
	_revisar_salida(delta)


# ---------- Luz de Chicomexochitl y viento ----------

func _crear_oscuridad_y_luz() -> void:
	_oscuro = CanvasModulate.new()
	_oscuro.color = Color(oscuridad, oscuridad, oscuridad * 1.08)
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

	_luz = PointLight2D.new()
	_luz.texture = tex
	_luz.texture_scale = radio_luz
	_luz.color = Color(1.0, 0.85, 0.6)
	_luz.energy = 1.1
	_chico = _buscar_chicomexochitl()
	var portador: Node = _chico if _chico else _jugador
	if portador:
		portador.add_child(_luz)

	# El amanecer que se cuela por la salida (crece al recordar todo)
	_luz_salida = PointLight2D.new()
	_luz_salida.texture = tex
	_luz_salida.texture_scale = 3.5
	_luz_salida.color = Color(1.0, 0.92, 0.8)
	_luz_salida.energy = 0.45
	_luz_salida.position = Vector2(ancho_pantalla * nombres_pantallas.size() - 40.0, 430.0)
	add_child(_luz_salida)


func _buscar_chicomexochitl() -> Node2D:
	for n in get_children():
		var s = n.get_script()
		if s and String(s.resource_path).to_lower().contains("chicomexochitl"):
			return n as Node2D
	return null


## La llaman las corrientes de aire cuando la ráfaga alcanza a Xochik de pie
func apagar_luz() -> void:
	if _apagada > 0.0:
		_apagada = segundos_apagada
		return
	_apagada = segundos_apagada
	Juego.sfx("latido", -2.0)
	_hud.estado("luz_apagada", true)
	if not _tip_apagada:
		_tip_apagada = true
		_decir("¡El viento me apagó!  Cuando silbe, agáchate  [S]  para cubrirme.", 3.5)


func _revisar_luz(delta: float) -> void:
	if _luz == null:
		return
	var energia := 1.1 + 0.08 * sin(_t * 9.0) * sin(_t * 2.3)
	if _apagada > 0.0:
		_apagada -= delta
		energia = 0.02
		if _apagada <= 0.0:
			Juego.sfx("vela", -3.0)
			_hud.estado("luz_apagada", false)
	_luz.energy = lerpf(_luz.energy, energia, 1.0 - exp(-12.0 * delta))
	if _chico:
		var g := lerpf(0.25, 1.0, clampf(_luz.energy, 0.0, 1.0))
		_chico.modulate = Color(g, g, g)


## La primera vez que silba el viento en la pantalla de Xochik, Chicomexochitl avisa
func _revisar_viento() -> void:
	if _tip_viento or not _jugando:
		return
	for c in get_tree().get_nodes_in_group("corrientes"):
		if c.estado == "aviso" and misma_pantalla((c as Node2D).global_position):
			_tip_viento = true
			_decir("¿Oyes ese silbido?  ¡Agáchate  [S]!", 2.2)
			return


# ---------- Recuerdos ----------

func _al_recoger(obj: ObjetoOfrenda) -> void:
	match obj.tipo:
		"papel_picado":
			_jugador.papel_picado += 1
			_decir("Papel picado: sella las manos de las ánimas  [E]", 3.0)
		"veladora":
			_jugador.ganar_vida()
		"recuerdo":
			var id: String = obj.id_recuerdo
			_recuerdos[id] = true
			_hud.llenar_ofrenda(id, obj.global_position)
			# El balero y la vela irán al altar; el retrato lo pone Xochik al final
			if id != "foto" and obj.textura:
				Juego.agregar_ofrenda(obj.textura.resource_path)
			_recordar(id)


func _recordar(id: String) -> void:
	_jugando = false
	_apagada = 0.0
	_hud.estado("luz_apagada", false)
	if _jugador:
		_jugador.atrapada = true
		_jugador.velocity = Vector2.ZERO
	await get_tree().create_timer(1.0, false).timeout
	Juego.musica("menu", 1.2)
	var r := RECUERDOS.new()
	add_child(r)
	await r.mostrar(IMAGENES.get(id, []))
	r.queue_free()
	Juego.musica("monte", 2.0)
	var lineas: PackedStringArray = despues_balero
	if id == "foto":
		lineas = despues_foto
	elif id == "vela":
		lineas = despues_vela
	for m in lineas:
		await _decir(m, segundos_por_mensaje)
	if _recuerdos.size() >= IMAGENES.size():
		_abrir_salida()
	if _jugador:
		_jugador.atrapada = false
	_jugando = true


func _abrir_salida() -> void:
	_completado = true
	Juego.sfx("campanas", -10.0)
	var tw := create_tween()
	tw.tween_property(_luz_salida, "energy", 1.6, 3.0)
	tw.parallel().tween_property(_luz_salida, "texture_scale", 6.0, 3.0)


## Al llegar a la salida: si ya recordó todo, pasa al pueblo
func _revisar_salida(delta: float) -> void:
	_aviso_falta = maxf(_aviso_falta - delta, 0.0)
	if _jugador == null or _saliendo:
		return
	if _jugador.global_position.x < ancho_pantalla * nombres_pantallas.size() - 70.0:
		return
	if _completado:
		_saliendo = true
		_jugador.atrapada = true
		Juego.ir_a(siguiente_nivel)
	elif _aviso_falta <= 0.0:
		_aviso_falta = 4.0
		_decir("Todavía no… algo de tu abuelo se quedó en la cueva.", 2.5)


func _game_over() -> void:
	_jugando = false
	await get_tree().create_timer(1.0, false).timeout
	Juego.game_over("La oscuridad de la cueva te envolvió…")


# ---------- Pantallas de cámara fija ----------

func pantalla_de(x: float) -> int:
	return clampi(int(floor(x / ancho_pantalla)), 0, nombres_pantallas.size() - 1)


func misma_pantalla(pos: Vector2) -> bool:
	return _jugador != null and pantalla_de(pos.x) == pantalla_de(_jugador.global_position.x)


func _revisar_pantalla(inicial: bool) -> void:
	if _jugador == null:
		return
	var p := pantalla_de(_jugador.global_position.x)
	if p == _pantalla:
		return
	var de_izquierda := p > _pantalla
	_pantalla = p
	if not inicial:
		var x := p * ancho_pantalla + (50.0 if de_izquierda else ancho_pantalla - 50.0)
		_jugador.punto_reaparicion = Vector2(x, _jugador.global_position.y - 10.0)
		_parpadeo()
	_fijar_camara(p)
	if not _vistas.has(p):
		_vistas[p] = true
		_mostrar_lugar(nombres_pantallas[p])


func _fijar_camara(p: int) -> void:
	if _camara == null:
		return
	_camara.zoom = Vector2.ONE
	_camara.limit_left = p * ancho_pantalla
	_camara.limit_right = (p + 1) * ancho_pantalla
	_camara.limit_top = 0
	_camara.limit_bottom = alto_pantalla
	_camara.reset_smoothing()


func _parpadeo() -> void:
	_cortina.color.a = 0.85
	var tw := create_tween()
	tw.tween_property(_cortina, "color:a", 0.0, 0.35)


func _mostrar_lugar(nombre: String) -> void:
	_lugar.text = nombre
	_lugar.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_lugar, "modulate:a", 0.9, 0.8)
	tw.tween_interval(2.5)
	tw.tween_property(_lugar, "modulate:a", 0.0, 1.2)


# ---------- HUD y mensajes ----------

func _crear_hud() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)

	_cortina = ColorRect.new()
	_cortina.color = Color(0, 0, 0, 0)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(_cortina)

	_hud = HUD.new()
	capa.add_child(_hud)
	_hud.titulo_ofrenda("R E C U E R D O S")
	_hud.agregar_ofrenda("balero", "El balero del abuelo", false, null, "desconocido")
	_hud.agregar_ofrenda("foto", "La foto del abuelo", false, null, "desconocido")
	_hud.agregar_ofrenda("vela", "La vela del abuelo", false, null, "desconocido")
	_hud.agregar_talisman("papel_picado", "interactuar", 0)
	_hud.ayuda([
		[["izquierda", "derecha"], "Moverse"],
		[["saltar"], "Saltar"],
		[["agachar"], "Agacharse (cubre la llama)"],
		[["interactuar"], "Tomar"],
	])

	_lugar = _label_base(22)
	_lugar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_lugar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lugar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lugar.position.y = 52
	_lugar.modulate.a = 0.0
	capa.add_child(_lugar)

	_mensaje = _label_base(20)
	_mensaje.set_anchors_preset(Control.PRESET_CENTER)
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mensaje.grow_vertical = Control.GROW_DIRECTION_BOTH
	_mensaje.modulate = Color(0.92, 0.92, 0.92)
	_mensaje.visible = false
	capa.add_child(_mensaje)


func _label_base(tam: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l


func _decir(txt: String, seg: float) -> void:
	_mensaje.text = txt
	_mensaje.visible = true
	_mensaje.modulate.a = 0.0
	var a := create_tween()
	a.tween_property(_mensaje, "modulate:a", 1.0, 0.4)
	await get_tree().create_timer(seg, false).timeout
	if _mensaje.text != txt:
		return
	var b := create_tween()
	b.tween_property(_mensaje, "modulate:a", 0.0, 0.5)
	await b.finished


func _asegurar_accion(nombre: String, tecla: Key) -> void:
	if InputMap.has_action(nombre):
		return
	InputMap.add_action(nombre)
	var ev := InputEventKey.new()
	ev.physical_keycode = tecla
	InputMap.action_add_event(nombre, ev)
