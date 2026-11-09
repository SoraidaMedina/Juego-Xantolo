extends CanvasLayer
## Autoload "Juego" — une todo el juego:
## orden de los niveles, transiciones con fundido, pausa [Esc] y pantalla de game over.
## Desde cualquier nivel: Juego.ir_a(ruta), Juego.siguiente_nivel(), Juego.game_over("texto").

const MENU := "res://scenes/MenuPrincipal.tscn"
## Orden en que se juegan los niveles. Para agregar uno, solo ponlo en la lista.
const NIVELES := [
	"res://scenes/niveles/Nivel1Sierra.tscn",
	"res://scenes/niveles/Nivel2Rio.tscn",
	"res://scenes/niveles/Nivel3Monte.tscn",
	"res://scenes/niveles/Nivel4Cueva.tscn",
	"res://scenes/niveles/NivelFinalPueblo.tscn",
]

## Título de capítulo que aparece al entrar a cada nivel: [número, nombre, una línea de la historia]
const CAPITULOS := {
	"res://scenes/niveles/Nivel1Sierra.tscn": ["CAPÍTULO I", "La Sierra de los Chaneques", "Las risas en la oscuridad no son de niños."],
	"res://scenes/niveles/Nivel2Rio.tscn": ["CAPÍTULO II", "El Río de la Llorona", "Cada Xantolo, su llanto baja con el agua."],
	"res://scenes/niveles/Nivel3Monte.tscn": ["CAPÍTULO III", "El Monte del Nahual", "Lo que se mueve, él lo encuentra."],
	"res://scenes/niveles/Nivel4Cueva.tscn": ["CAPÍTULO IV", "La Cueva del Abuelo", "La montaña guarda lo que tú quisiste olvidar."],
	"res://scenes/niveles/NivelFinalPueblo.tscn": ["CAPÍTULO V", "El Pueblo: Xantolo roto", "Antes del amanecer, el altar debe arder de nuevo."],
}
const ARCHIVO_PARTIDA := "user://partida.cfg"

## Música de cada escena (assets/audio/musica/<nombre>.ogg)
const MUSICA_POR_ESCENA := {
	"res://scenes/MenuPrincipal.tscn": "menu",
	"res://scenes/niveles/Nivel1Sierra.tscn": "sierra",
	"res://scenes/niveles/Nivel2Rio.tscn": "rio",
	"res://scenes/niveles/Nivel3Monte.tscn": "monte",
	"res://scenes/niveles/Nivel4Cueva.tscn": "monte",
	"res://scenes/niveles/NivelFinalPueblo.tscn": "menu",   # al restaurar el ritual cambia a "pueblo"
}
const VOLUMEN_MUSICA_DB := -6.0

const GRIS_TEXTO := Color(0.85, 0.85, 0.85)
const GRIS_TENUE := Color(0.55, 0.55, 0.55)

var _negro: ColorRect
var _pausa: Control
var _gameover: Control
var _texto_gameover: Label
var _cambiando := false
## Lo que Xochik ha recuperado en el camino (rutas de imagen). El altar final se arma con esto.
var ofrenda: Array[String] = []
## Sustos (jumpscares) activados. Se cambia desde el menú principal.
var sustos_activos := true
## Volumen (0 a 1) de la música y de los efectos; se guarda junto con la partida
var volumen_musica := 0.8
var volumen_efectos := 0.9
## Mientras se ve un recuerdo o un título de capítulo no se puede pausar
var bloquear_pausa := false
var _capitulo: Control
var _cap_numero: Label
var _cap_titulo: Label
var _cap_linea: Label
var _saltar_capitulo := false
var _capa_susto: CanvasLayer
var _imagen_susto: TextureRect
var _susto_en_curso := false
var _musica: Array[AudioStreamPlayer] = []
var _musica_actual := 0
var _nombre_musica := ""
var _sfx: Array[AudioStreamPlayer] = []
var _cache_sfx := {}


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_asegurar_accion("pausa", KEY_ESCAPE)
	_asegurar_accion("pausa", KEY_P)
	_asegurar_accion("interactuar", KEY_E)
	_asegurar_accion("usar_copal", KEY_Q)
	_asegurar_accion("ocultar_luz", KEY_F)
	_asegurar_accion("lanzar_piedra", KEY_R)
	_asegurar_accion("amuleto", KEY_C)
	_asegurar_accion("esparcir_petalos", KEY_V)
	_crear_pausa()
	_crear_gameover()
	_negro = ColorRect.new()
	_negro.color = Color(0, 0, 0, 0)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_negro)
	_crear_buses()
	_crear_audio()
	_cargar_ajustes()
	_crear_capitulo()
	_actualizar_musica.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if _capitulo and _capitulo.visible and event.is_pressed() and not event.is_echo():
		_saltar_capitulo = true
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("pausa"):
		return
	if _pausa.visible:
		reanudar()
	elif _puede_pausar():
		pausar()
	get_viewport().set_input_as_handled()


# ---------- Cambiar de escena ----------

## Va a la escena indicada. Si la ruta está vacía, pasa al siguiente nivel de la lista.
func ir_a(ruta: String) -> void:
	if ruta == "":
		siguiente_nivel()
	else:
		cambiar_escena(ruta)


func siguiente_nivel() -> void:
	var i := NIVELES.find(_escena_actual())
	if i >= 0 and i + 1 < NIVELES.size():
		cambiar_escena(NIVELES[i + 1])
	else:
		ir_al_menu()


func nuevo_juego() -> void:
	ofrenda.clear()
	cambiar_escena(NIVELES[0])


## Sigue desde el último nivel al que se llegó, con la ofrenda que se llevaba
func continuar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO_PARTIDA) != OK:
		nuevo_juego()
		return
	var nivel: String = cfg.get_value("partida", "nivel", NIVELES[0])
	ofrenda.clear()
	for ruta in cfg.get_value("partida", "ofrenda", []):
		ofrenda.append(str(ruta))
	cambiar_escena(nivel if NIVELES.has(nivel) else NIVELES[0])


func hay_partida() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(ARCHIVO_PARTIDA) == OK and NIVELES.has(cfg.get_value("partida", "nivel", ""))


func _guardar_partida(nivel: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(ARCHIVO_PARTIDA)
	cfg.set_value("partida", "nivel", nivel)
	cfg.set_value("partida", "ofrenda", Array(ofrenda))
	cfg.save(ARCHIVO_PARTIDA)


func borrar_partida() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO_PARTIDA) == OK and cfg.has_section("partida"):
		cfg.erase_section("partida")
		cfg.save(ARCHIVO_PARTIDA)


func reiniciar_nivel() -> void:
	cambiar_escena(_escena_actual(), false)


func ir_al_menu() -> void:
	cambiar_escena(MENU)


## con_titulo: muestra el título del capítulo (no al reintentar el mismo nivel)
func cambiar_escena(ruta: String, con_titulo: bool = true) -> void:
	if _cambiando or ruta == "":
		return
	_cambiando = true
	_negro.mouse_filter = Control.MOUSE_FILTER_STOP
	var a := create_tween()
	a.tween_property(_negro, "color:a", 1.0, 0.6)
	await a.finished
	_pausa.visible = false
	_gameover.visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file(ruta)
	await get_tree().process_frame
	await get_tree().process_frame
	_actualizar_musica()
	if NIVELES.has(ruta):
		_guardar_partida(ruta)
		if con_titulo and CAPITULOS.has(ruta):
			await _mostrar_capitulo(CAPITULOS[ruta])
	var b := create_tween()
	b.tween_property(_negro, "color:a", 0.0, 0.8)
	await b.finished
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cambiando = false


func _escena_actual() -> String:
	var e := get_tree().current_scene
	return e.scene_file_path if e else ""


func agregar_ofrenda(ruta: String) -> void:
	if ruta != "" and not ofrenda.has(ruta):
		ofrenda.append(ruta)


# ---------- Pausa ----------

func _puede_pausar() -> bool:
	return not _cambiando and not bloquear_pausa and not _gameover.visible and NIVELES.has(_escena_actual())


func pausar() -> void:
	get_tree().paused = true
	_volumen_musica(VOLUMEN_MUSICA_DB - 10.0)
	_pausa.visible = true
	_enfocar_primero(_pausa)


func reanudar() -> void:
	guardar_ajustes()
	_volumen_musica(VOLUMEN_MUSICA_DB)
	_pausa.visible = false
	get_tree().paused = false


# ---------- Game over ----------

## Llamar cuando Xochik se queda sin vidas
func game_over(texto: String = "Las ánimas te alcanzaron…") -> void:
	if _gameover.visible or _cambiando:
		return
	_pausa.visible = false
	get_tree().paused = true
	_texto_gameover.text = texto
	sfx("atrapada")
	_volumen_musica(VOLUMEN_MUSICA_DB - 14.0)
	_gameover.modulate.a = 0.0
	_gameover.visible = true
	var tw := create_tween()
	tw.tween_property(_gameover, "modulate:a", 1.0, 1.2)
	_enfocar_primero(_gameover)


# ---------- Interfaz ----------

func _crear_pausa() -> void:
	_pausa = _panel_oscuro(0.75)
	var caja := _caja_central(_pausa)
	caja.add_child(crear_titulo("PAUSA", 40))
	caja.add_child(_espacio(16))
	var b_seguir := crear_boton("Continuar")
	b_seguir.pressed.connect(reanudar)
	caja.add_child(b_seguir)
	var b_reiniciar := crear_boton("Reiniciar nivel")
	b_reiniciar.pressed.connect(reiniciar_nivel)
	caja.add_child(b_reiniciar)
	var b_menu := crear_boton("Menú principal")
	b_menu.pressed.connect(ir_al_menu)
	caja.add_child(b_menu)
	caja.add_child(_espacio(18))
	caja.add_child(crear_controles_volumen())
	caja.add_child(_espacio(16))
	var ayuda := crear_texto("[Esc] Continuar", 13)
	ayuda.modulate = GRIS_TENUE
	caja.add_child(ayuda)


func _crear_gameover() -> void:
	_gameover = _panel_oscuro(0.85)
	var caja := _caja_central(_gameover)
	_texto_gameover = crear_titulo("", 28)
	caja.add_child(_texto_gameover)
	caja.add_child(_espacio(8))
	var sub := crear_texto("La vela de Chicomexochitl aún no se apaga…", 15)
	sub.modulate = GRIS_TENUE
	caja.add_child(sub)
	caja.add_child(_espacio(20))
	var b_otra := crear_boton("Intentar de nuevo")
	b_otra.pressed.connect(reiniciar_nivel)
	caja.add_child(b_otra)
	var b_menu := crear_boton("Menú principal")
	b_menu.pressed.connect(ir_al_menu)
	caja.add_child(b_menu)


func _panel_oscuro(alfa: float) -> Control:
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, alfa)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.visible = false
	add_child(fondo)
	return fondo


func _caja_central(padre: Control) -> VBoxContainer:
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	padre.add_child(centro)
	var caja := VBoxContainer.new()
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 6)
	centro.add_child(caja)
	return caja


func _espacio(alto: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, alto)
	return c


func _enfocar_primero(raiz: Node) -> void:
	for n in raiz.find_children("*", "Button", true, false):
		(n as Button).grab_focus()
		return


## Botón de texto en escala de grises (también lo usa el menú principal)
func crear_boton(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.flat = true
	b.custom_minimum_size = Vector2(260, 40)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", GRIS_TENUE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", GRIS_TEXTO)
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 4)
	var vacio := StyleBoxEmpty.new()
	var marca := StyleBoxFlat.new()
	marca.bg_color = Color(1, 1, 1, 0.06)
	marca.border_color = Color(1, 1, 1, 0.35)
	marca.border_width_bottom = 1
	marca.border_width_top = 1
	b.add_theme_stylebox_override("normal", vacio)
	b.add_theme_stylebox_override("hover", marca)
	b.add_theme_stylebox_override("focus", marca)
	b.add_theme_stylebox_override("pressed", marca)
	# El mouse y el teclado marcan el mismo botón
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(sfx.bind("ui", -6.0))
	return b


func crear_titulo(texto: String, tam: int) -> Label:
	var l := crear_texto(texto, tam)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 8)
	return l


func crear_texto(texto: String, tam: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", GRIS_TEXTO)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l


func _asegurar_accion(nombre: String, tecla: Key) -> void:
	if not InputMap.has_action(nombre):
		InputMap.add_action(nombre)
	for ev in InputMap.action_get_events(nombre):
		if ev is InputEventKey and ev.physical_keycode == tecla:
			return
	var nuevo := InputEventKey.new()
	nuevo.physical_keycode = tecla
	InputMap.action_add_event(nombre, nuevo)


# ---------- Sustos ----------

## Susto fuerte: la cara del enemigo llena la pantalla con un golpe de sonido (al atraparte)
func susto(nombre: String) -> void:
	if not sustos_activos or _susto_en_curso:
		return
	await _mostrar_susto(nombre, 1.0, 0.65, "susto", 0.0)


## Susto de ambiente: un vistazo breve y tenue, con un susurro (no hace daño)
func susto_ambiente(nombre: String) -> void:
	if not sustos_activos or _susto_en_curso:
		return
	await _mostrar_susto(nombre, 0.4, 0.22, "susto_suave", -4.0)


func _mostrar_susto(nombre: String, alfa: float, dur: float, sonido: String, vol: float) -> void:
	var ruta := "res://assets/sustos/susto_%s.png" % nombre
	if not ResourceLoader.exists(ruta):
		return
	_susto_en_curso = true
	if _capa_susto == null:
		_capa_susto = CanvasLayer.new()
		_capa_susto.layer = 95
		add_child(_capa_susto)
		_imagen_susto = TextureRect.new()
		_imagen_susto.set_anchors_preset(Control.PRESET_FULL_RECT)
		_imagen_susto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_imagen_susto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_imagen_susto.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_imagen_susto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_imagen_susto.pivot_offset = get_viewport().get_visible_rect().size / 2.0
		_capa_susto.add_child(_imagen_susto)
	_imagen_susto.texture = load(ruta)
	_imagen_susto.modulate = Color(1, 1, 1, alfa)
	_imagen_susto.scale = Vector2.ONE
	_imagen_susto.visible = true
	sfx(sonido, vol)
	# Temblor, parpadeo y acercamiento
	var t := 0.0
	while t < dur:
		_imagen_susto.position = Vector2(randf_range(-14, 14), randf_range(-10, 10)) * alfa
		_imagen_susto.scale = Vector2.ONE * (1.0 + t / dur * 0.08)
		_imagen_susto.visible = randf() > 0.12
		await get_tree().create_timer(0.03, true, false, true).timeout
		t += 0.03
	_imagen_susto.visible = true
	_imagen_susto.position = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(_imagen_susto, "modulate:a", 0.0, 0.25)
	await tw.finished
	_imagen_susto.visible = false
	_susto_en_curso = false


# ---------- Audio ----------

func _crear_audio() -> void:
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		m.bus = "Musica"
		add_child(m)
		_musica.append(m)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Efectos"
		add_child(p)
		_sfx.append(p)


## Dos canales de audio (música y efectos) para poder ajustar su volumen por separado
func _crear_buses() -> void:
	for nombre in ["Musica", "Efectos"]:
		if AudioServer.get_bus_index(nombre) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nombre)
			AudioServer.set_bus_send(i, "Master")


func ajustar_volumen(canal: String, valor: float) -> void:
	valor = clampf(valor, 0.0, 1.0)
	if canal == "Musica":
		volumen_musica = valor
	else:
		volumen_efectos = valor
	var i := AudioServer.get_bus_index(canal)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(valor, 0.0001)))
		AudioServer.set_bus_mute(i, valor <= 0.01)


func guardar_ajustes() -> void:
	var cfg := ConfigFile.new()
	cfg.load(ARCHIVO_PARTIDA)
	cfg.set_value("ajustes", "musica", volumen_musica)
	cfg.set_value("ajustes", "efectos", volumen_efectos)
	cfg.set_value("ajustes", "sustos", sustos_activos)
	cfg.save(ARCHIVO_PARTIDA)


func _cargar_ajustes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO_PARTIDA) == OK:
		volumen_musica = float(cfg.get_value("ajustes", "musica", volumen_musica))
		volumen_efectos = float(cfg.get_value("ajustes", "efectos", volumen_efectos))
		sustos_activos = bool(cfg.get_value("ajustes", "sustos", sustos_activos))
	ajustar_volumen("Musica", volumen_musica)
	ajustar_volumen("Efectos", volumen_efectos)


## Dos barras (Música y Efectos) listas para poner en un menú; guardan al soltarlas
func crear_controles_volumen() -> VBoxContainer:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	caja.add_child(_fila_volumen("Música", "Musica", volumen_musica))
	caja.add_child(_fila_volumen("Efectos", "Efectos", volumen_efectos))
	return caja


func _fila_volumen(texto: String, canal: String, valor: float) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	var nombre := crear_texto(texto, 16)
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nombre.custom_minimum_size = Vector2(90, 0)
	fila.add_child(nombre)
	var barra := HSlider.new()
	barra.min_value = 0.0
	barra.max_value = 1.0
	barra.step = 0.05
	barra.value = valor
	barra.custom_minimum_size = Vector2(200, 24)
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pista := StyleBoxFlat.new()
	pista.bg_color = Color(0.25, 0.25, 0.25)
	pista.content_margin_top = 3
	pista.content_margin_bottom = 3
	pista.set_corner_radius_all(2)
	var lleno := StyleBoxFlat.new()
	lleno.bg_color = Color(0.85, 0.85, 0.85)
	lleno.set_corner_radius_all(2)
	barra.add_theme_stylebox_override("slider", pista)
	barra.add_theme_stylebox_override("grabber_area", lleno)
	barra.add_theme_stylebox_override("grabber_area_highlight", lleno)
	fila.add_child(barra)
	var porcentaje := crear_texto("%d%%" % roundi(valor * 100), 14)
	porcentaje.custom_minimum_size = Vector2(48, 0)
	porcentaje.modulate = GRIS_TENUE
	fila.add_child(porcentaje)
	barra.value_changed.connect(_al_mover_volumen.bind(canal, porcentaje))
	barra.drag_ended.connect(_al_soltar_volumen)
	return fila


func _al_mover_volumen(valor: float, canal: String, porcentaje: Label) -> void:
	ajustar_volumen(canal, valor)
	porcentaje.text = "%d%%" % roundi(valor * 100)
	if canal == "Efectos":
		sfx("ui", -4.0)


func _al_soltar_volumen(_cambio: bool) -> void:
	guardar_ajustes()


# ---------- Títulos de capítulo ----------

func _crear_capitulo() -> void:
	_capitulo = Control.new()
	_capitulo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capitulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capitulo.visible = false
	add_child(_capitulo)
	var caja := _caja_central(_capitulo)
	caja.add_theme_constant_override("separation", 10)
	_cap_numero = crear_texto("", 15)
	_cap_numero.modulate = GRIS_TENUE
	caja.add_child(_cap_numero)
	_cap_titulo = crear_titulo("", 40)
	caja.add_child(_cap_titulo)
	var raya := ColorRect.new()
	raya.color = Color(1, 1, 1, 0.35)
	raya.custom_minimum_size = Vector2(220, 1)
	raya.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	caja.add_child(raya)
	_cap_linea = crear_texto("", 17)
	_cap_linea.modulate = Color(0.75, 0.75, 0.75)
	caja.add_child(_cap_linea)


## Pantalla negra con el capítulo; el nivel espera en pausa. Cualquier tecla la adelanta.
func _mostrar_capitulo(datos: Array) -> void:
	get_tree().paused = true
	bloquear_pausa = true
	_cap_numero.text = " ".join(String(datos[0]).split(""))
	_cap_titulo.text = datos[1]
	_cap_linea.text = datos[2]
	_capitulo.modulate.a = 0.0
	_capitulo.visible = true
	_saltar_capitulo = false
	var entra := create_tween()
	entra.tween_property(_capitulo, "modulate:a", 1.0, 0.9)
	await entra.finished
	var t := 0.0
	while t < 2.8 and not _saltar_capitulo:
		await get_tree().process_frame
		t += get_process_delta_time()
	var sale := create_tween()
	sale.tween_property(_capitulo, "modulate:a", 0.0, 0.7)
	await sale.finished
	_capitulo.visible = false
	bloquear_pausa = false
	get_tree().paused = false


func _actualizar_musica() -> void:
	musica(MUSICA_POR_ESCENA.get(_escena_actual(), ""))


## Cambia la música con un fundido cruzado. "" = silencio.
func musica(nombre: String, fundido: float = 1.5) -> void:
	if nombre == _nombre_musica:
		_volumen_musica(VOLUMEN_MUSICA_DB)
		return
	_nombre_musica = nombre
	var viejo := _musica[_musica_actual]
	_musica_actual = 1 - _musica_actual
	var nuevo := _musica[_musica_actual]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(viejo, "volume_db", -80.0, fundido)
	tw.chain().tween_callback(viejo.stop)
	var ruta := "res://assets/audio/musica/%s.ogg" % nombre
	if nombre == "" or not ResourceLoader.exists(ruta):
		return
	var stream = load(ruta)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	nuevo.stream = stream
	nuevo.volume_db = -40.0
	nuevo.play()
	create_tween().tween_property(nuevo, "volume_db", VOLUMEN_MUSICA_DB, fundido)


func _volumen_musica(db: float) -> void:
	if _musica.is_empty():
		return
	create_tween().tween_property(_musica[_musica_actual], "volume_db", db, 0.4)


## Efecto de sonido de assets/audio/sfx/<nombre>.ogg. volumen_db: 0 = normal, negativo = más bajo.
func sfx(nombre: String, volumen_db: float = 0.0, tono: float = 1.0) -> void:
	if not _cache_sfx.has(nombre):
		var ruta := "res://assets/audio/sfx/%s.ogg" % nombre
		_cache_sfx[nombre] = load(ruta) if ResourceLoader.exists(ruta) else null
	var stream = _cache_sfx[nombre]
	if stream == null:
		return
	var libre: AudioStreamPlayer = null
	for p in _sfx:
		if not p.playing:
			libre = p
			break
	if libre == null:
		libre = _sfx[0]
	libre.stream = stream
	libre.volume_db = volumen_db
	libre.pitch_scale = tono
	libre.play()
