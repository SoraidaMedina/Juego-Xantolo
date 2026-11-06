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
	"res://scenes/niveles/NivelFinalPueblo.tscn",
]

## Música de cada escena (assets/audio/musica/<nombre>.ogg)
const MUSICA_POR_ESCENA := {
	"res://scenes/MenuPrincipal.tscn": "menu",
	"res://scenes/niveles/Nivel1Sierra.tscn": "sierra",
	"res://scenes/niveles/Nivel2Rio.tscn": "rio",
	"res://scenes/niveles/Nivel3Monte.tscn": "monte",
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
	_crear_pausa()
	_crear_gameover()
	_negro = ColorRect.new()
	_negro.color = Color(0, 0, 0, 0)
	_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_negro)
	_crear_audio()
	_actualizar_musica.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
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


func reiniciar_nivel() -> void:
	cambiar_escena(_escena_actual())


func ir_al_menu() -> void:
	cambiar_escena(MENU)


func cambiar_escena(ruta: String) -> void:
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
	return not _cambiando and not _gameover.visible and NIVELES.has(_escena_actual())


func pausar() -> void:
	get_tree().paused = true
	_volumen_musica(VOLUMEN_MUSICA_DB - 10.0)
	_pausa.visible = true
	_enfocar_primero(_pausa)


func reanudar() -> void:
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


# ---------- Audio ----------

func _crear_audio() -> void:
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = -80.0
		add_child(m)
		_musica.append(m)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)


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
