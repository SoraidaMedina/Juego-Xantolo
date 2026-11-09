extends Node2D
## Nivel 2 — El Río de la Llorona
## Objetivo: encontrar la pertenencia correcta de sus hijos entre señuelos
## y entregársela: acercarse con ella en la mano y pulsar [E] (o dejar que te alcance).

@export var ancho_nivel: int = 1152
@export var alto_nivel: int = 648
@export_file("*.tscn") var siguiente_nivel: String = ""
## (Opcional) Un mensaje extra antes del diálogo. Déjalo vacío si no lo usas.
@export_multiline var pista_inicial: String = ""

## Mensajes de ayuda que salen después de la pista (uno tras otro)
## Diálogo de la abuela (o mensajes en pantalla si no hay abuela), en orden
@export var mensajes_tutorial: PackedStringArray = [
	"Ay, mija… este es el río de la Llorona. Cada noche de Xantolo busca a sus hijos, llorando.",
	"Su llanto no es de maldad, es de tristeza. Solo se calma si le devuelves algo de su hijo.",
	"Su hijo era muy inquieto. Su juguete favorito lo enredaba con un cordel, lo lanzaba… y bailaba dando vueltas sobre la tierra.",
	"Por la orilla hay cosas tiradas. Toma una con [E]. Solo puedes cargar una: si tomas otra, la primera regresa a su lugar.",
	"Cuando tengas la correcta, acércate a la Llorona y entrégasela con [E]. Si te equivocas, perderás una vida.",
	"Si te ve con las manos vacías, te seguirá: escóndete en un arbusto y agáchate [%agachar%].",
	"Y cuidado con el agua, mija: salta de piedra en piedra. Ve con Dios.",
]
@export var segundos_por_mensaje: float = 4.0

var _jugador: Node
var _aviso_persecucion := false
var _hud  # script/hud.gd
const HUD := preload("res://script/hud.gd")
var _mensaje: Label
var _terminado := false
var _llevaba := ""
var _aviso_cambio := false


func _ready() -> void:
	_asegurar_accion("interactuar", KEY_E)
	_jugador = get_tree().get_first_node_in_group("jugador")
	_configurar_camara()
	_crear_hud()
	if _jugador:
		_hud.preparar(_jugador)
		_jugador.sin_vidas.connect(_game_over)
	for p in get_tree().get_nodes_in_group("pertenencias"):
		p.tomada.connect(_al_tomar)
	var llorona = get_tree().get_first_node_in_group("llorona")
	if llorona:
		llorona.calmada.connect(_victoria)
	_actualizar_hud()
	_tutorial()


func _tutorial() -> void:
	# Si hay una Abuela en el nivel, ella da la pista y las instrucciones
	var abuela = get_tree().get_first_node_in_group("abuela")
	if abuela:
		var lista := PackedStringArray()
		var pista := pista_inicial
		if pista.begins_with("Chicomexochitl:"):
			pista = pista.trim_prefix("Chicomexochitl:").strip_edges().trim_prefix("\"").trim_suffix("\"")
		if pista.strip_edges() != "":
			lista.append(_teclas(pista))
		for m in mensajes_tutorial:
			lista.append(_teclas(m))
		await get_tree().process_frame
		abuela.decir(lista)
		return
	if pista_inicial.strip_edges() != "":
		_mostrar_mensaje(_teclas(pista_inicial), 5.0)
		await get_tree().create_timer(5.5, false).timeout
	for m in mensajes_tutorial:
		if _terminado:
			return
		_mostrar_mensaje(_teclas(m), segundos_por_mensaje)
		await get_tree().create_timer(segundos_por_mensaje + 1.2, false).timeout


func _process(_delta: float) -> void:
	_actualizar_hud()
	# La primera vez que la Llorona te persigue, recuerda cómo esconderse
	if not _aviso_persecucion and not _terminado:
		var ll = get_tree().get_first_node_in_group("llorona")
		if ll and ll.estado == "persecucion":
			_aviso_persecucion = true
			Juego.susto_ambiente("llorona")
			_mostrar_mensaje(_teclas("¡Te vio! Corre a un arbusto y agáchate [%agachar%]"), 3.0)


## Explica por qué "regresa" el objeto anterior al tomar otro
func _al_tomar(obj: Node) -> void:
	if _llevaba != "" and _llevaba != obj.nombre and not _aviso_cambio:
		_aviso_cambio = true
		_mostrar_mensaje("Dejaste " + _llevaba.to_lower() + " en su lugar: solo puedes cargar una cosa.", 3.0)
	_llevaba = obj.nombre
	_actualizar_hud()


func _configurar_camara() -> void:
	if _jugador == null:
		return
	var camara := _jugador.get_node_or_null("Camera2D") as Camera2D
	if camara == null:
		return
	camara.zoom = Vector2.ONE
	# Si hay un Sprite2D llamado "Fondo", los límites salen de su tamaño real
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


func _victoria() -> void:
	_terminado = true
	for p in get_tree().get_nodes_in_group("pertenencias"):
		if p.es_correcto and p.textura:
			Juego.agregar_ofrenda(p.textura.resource_path)
	var ll = get_tree().get_first_node_in_group("llorona")
	_hud.llenar_ofrenda("juguete", ll.global_position if ll else null)
	_hud.en_mano(null, "")
	_hud.objetivo("")
	_mostrar_mensaje("La Llorona reconoce a sus hijos...\nY por fin encuentra paz", 0.0)
	await get_tree().create_timer(4.0, false).timeout
	Juego.ir_a(siguiente_nivel)  # vacío = siguiente nivel de la lista


func _game_over() -> void:
	_terminado = true
	await get_tree().create_timer(1.0, false).timeout
	Juego.game_over("El llanto del río te alcanzó…")


# ---------- HUD ----------

func _crear_hud() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	_hud = HUD.new()
	capa.add_child(_hud)
	_hud.agregar_ofrenda_del_viaje(true)
	_mensaje = _label_base(20)
	_mensaje.set_anchors_preset(Control.PRESET_CENTER)
	_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mensaje.grow_vertical = Control.GROW_DIRECTION_BOTH
	_mensaje.modulate = Color(0.95, 0.95, 0.95)
	_mensaje.visible = false
	capa.add_child(_mensaje)

	# Controles siempre visibles abajo
	_hud.ayuda([
		[["izquierda", "derecha"], "Moverse"],
		[["saltar"], "Saltar"],
		[["agachar"], "Agacharse / esconderse"],
		[["interactuar"], "Tomar / entregar"],
	])


## Cambia %accion% por la tecla que tiene asignada en el Mapa de Entrada
func _teclas(txt: String) -> String:
	for accion in ["izquierda", "derecha", "saltar", "agachar"]:
		var tecla: String = accion
		if InputMap.has_action(accion):
			# Junta todas las teclas de la acción: ej. "S / Abajo"
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


func _label_base(tam: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	return l


func _actualizar_hud() -> void:
	if _jugador == null or _hud == null:
		return
	if _terminado:
		return
	var en_mano = _jugador.objeto_en_mano
	if en_mano:
		_llevaba = en_mano.nombre
		_hud.en_mano(en_mano.textura, _llevaba)
		_hud.objetivo("Acércate a la Llorona y entrégaselo  [E]")
	else:
		_llevaba = ""
		_hud.en_mano(null, "")
		_hud.objetivo("Devuélvele a la Llorona el juguete favorito de su hijo")


func _mostrar_mensaje(txt: String, duracion: float) -> void:
	_mensaje.text = txt
	_mensaje.modulate.a = 1.0
	_mensaje.visible = true
	if duracion > 0.0:
		await get_tree().create_timer(duracion, false).timeout
		if not _terminado:
			var tw := create_tween()
			tw.tween_property(_mensaje, "modulate:a", 0.0, 1.0)


func _asegurar_accion(nombre: String, tecla: Key) -> void:
	if InputMap.has_action(nombre):
		return
	InputMap.add_action(nombre)
	var ev := InputEventKey.new()
	ev.physical_keycode = tecla
	InputMap.action_add_event(nombre, ev)
