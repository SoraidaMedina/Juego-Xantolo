extends Control
## HUD con íconos (no con números): cada vida es una veladora encendida, la ofrenda son
## sus piezas que se iluminan al encontrarlas, los talismanes llevan su tecla y cuántos quedan.
##
## Uso desde un nivel (dentro de su CanvasLayer):
##   const HUD := preload("res://script/hud.gd")
##   var hud := HUD.new();  capa.add_child(hud);  hud.preparar(jugador)
##   hud.agregar_ofrenda("vela", "Vela");          hud.llenar_ofrenda("vela", pos_en_el_mundo)
##   hud.agregar_talisman("copal", "usar_copal", 0); hud.talisman("copal", 2)
##   hud.mostrar_luz();  hud.luz(valor, maximo, agotada, oculta)
##   hud.alerta("EL NAHUAL VIGILA", true);  hud.objetivo("…");  hud.ayuda([...])

const RUTA_ICONO := "res://assets/hud/%s.png"
const MARCO := preload("res://assets/hud/marco.png")
const VIDA := preload("res://assets/hud/vida.png")
const VIDA_APAGADA := preload("res://assets/hud/vida_apagada.png")
const LLAMA := preload("res://assets/hud/llama.png")
const LUZ_OCULTA := preload("res://assets/hud/luz_oculta.png")
const OJO := preload("res://assets/hud/ojo.png")
const MANO := preload("res://assets/hud/mano.png")
## Tamaño de cada pixel de los íconos (los PNG están a 1x; se agrandan en múltiplos exactos)
const PX := 3
const PX_CHICO := 2

## Propiedades de Xochik que el HUD lee solo, si el nivel registró ese talismán
const TALISMAN_DEL_JUGADOR := {"papel_picado": "papel_picado", "amuleto": "amuletos", "petalos": "petalos"}
const ESTADOS := {
	"escondida": ["escondida", "Escondida"],
	"protegida": ["amuleto", "Amuleto activo"],
	"luz_oculta": ["luz_oculta", "Luz oculta"],
	"luz_apagada": ["vida_apagada", "El viento apagó la llama"],
}

var _jugador: Node
var _columna: VBoxContainer
var _fila_vidas: HBoxContainer
var _iconos_vida: Array[TextureRect] = []
var _vidas_mostradas := -1
var _fila_talismanes: HBoxContainer
var _separador: ColorRect
var _talismanes := {}          # id -> {"icono", "cantidad", "valor", "caja"}
var _fila_luz: HBoxContainer
var _icono_luz: TextureRect
var _barra: BarraLuz
var _fila_mano: HBoxContainer
var _textura_mano: TextureRect
var _nombre_mano: Label
var _fila_estados: HBoxContainer
var _estados := {}             # id -> PanelContainer
var _objetivo: Label
var _panel_ofrenda: PanelContainer
var _fila_ofrenda: HBoxContainer
var _titulo_ofrenda: Label
var _ofrenda := {}             # id -> {"icono", "lleno", "textura", "vacia"}
var _alerta: HBoxContainer
var _texto_alerta: Label
var _ayuda: HBoxContainer
var _t := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_construir()


func preparar(jugador: Node) -> void:
	_jugador = jugador
	if _jugador == null:
		return
	_jugador.vidas_cambiadas.connect(_al_cambiar_vidas)
	_crear_vidas(int(_jugador.vidas_max))
	_al_cambiar_vidas(int(_jugador.vidas))


func _process(delta: float) -> void:
	_t += delta
	if _jugador:
		estado("escondida", _jugador.esta_escondida())
		estado("protegida", bool(_jugador.protegida))
		for id in TALISMAN_DEL_JUGADOR:
			if _talismanes.has(id):
				talisman(id, int(_jugador.get(TALISMAN_DEL_JUGADOR[id])))
		# La última veladora tiembla: queda una sola vida
		if _vidas_mostradas == 1 and not _iconos_vida.is_empty():
			var f := 0.75 + 0.25 * sin(_t * 11.0) * sin(_t * 3.7)
			_iconos_vida[0].modulate = Color(f, f, f)
	if _alerta.visible:
		var a := 0.55 + 0.45 * absf(sin(_t * 3.0))
		_alerta.modulate.a = a
	# Mientras la abuela habla, los paneles se desvanecen para no tapar su diálogo
	var objetivo_alfa := 0.0 if _alguien_habla() else 1.0
	var paso := 1.0 - exp(-10.0 * delta)
	_columna.modulate.a = lerpf(_columna.modulate.a, objetivo_alfa, paso)
	_panel_ofrenda.modulate.a = lerpf(_panel_ofrenda.modulate.a, objetivo_alfa, paso)


func _alguien_habla() -> bool:
	for a in get_tree().get_nodes_in_group("abuela"):
		if a.has_method("esta_hablando") and a.esta_hablando():
			return true
	return false


# ================= Construcción =================

func _construir() -> void:
	_columna = VBoxContainer.new()
	_columna.position = Vector2(12, 10)
	_columna.add_theme_constant_override("separation", 6)
	_columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_columna)

	var panel := _panel_bordado()
	_columna.add_child(panel)
	var dentro := VBoxContainer.new()
	dentro.add_theme_constant_override("separation", 6)
	panel.add_child(dentro)

	var franja := _fila(14)
	dentro.add_child(franja)
	_fila_vidas = _fila(3)
	franja.add_child(_fila_vidas)
	_separador = ColorRect.new()
	_separador.color = Color(0.55, 0.55, 0.55, 0.6)
	_separador.custom_minimum_size = Vector2(1, 44)
	_separador.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_separador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_separador.visible = false
	franja.add_child(_separador)
	_fila_talismanes = _fila(14)
	_fila_talismanes.visible = false
	franja.add_child(_fila_talismanes)
	_fila_luz = _fila(6)
	_fila_luz.visible = false
	dentro.add_child(_fila_luz)
	_fila_mano = _fila(8)
	_fila_mano.visible = false
	dentro.add_child(_fila_mano)

	_fila_estados = _fila(6)
	_columna.add_child(_fila_estados)
	_objetivo = _etiqueta("", 14)
	_objetivo.modulate = Color(0.85, 0.85, 0.85)
	_objetivo.visible = false
	_columna.add_child(_objetivo)

	# Ofrenda, arriba a la derecha
	_panel_ofrenda = _panel_bordado()
	_panel_ofrenda.anchor_left = 1.0
	_panel_ofrenda.anchor_right = 1.0
	_panel_ofrenda.offset_left = -12.0
	_panel_ofrenda.offset_right = -12.0
	_panel_ofrenda.offset_top = 10.0
	_panel_ofrenda.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel_ofrenda.visible = false
	add_child(_panel_ofrenda)
	var col_ofrenda := VBoxContainer.new()
	col_ofrenda.add_theme_constant_override("separation", 4)
	_panel_ofrenda.add_child(col_ofrenda)
	_titulo_ofrenda = _etiqueta("O F R E N D A", 11)
	_titulo_ofrenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo_ofrenda.modulate = Color(0.7, 0.7, 0.7)
	col_ofrenda.add_child(_titulo_ofrenda)
	_fila_ofrenda = _fila(6)
	_fila_ofrenda.alignment = BoxContainer.ALIGNMENT_CENTER
	col_ofrenda.add_child(_fila_ofrenda)

	# Alerta arriba al centro (el Nahual vigila)
	_alerta = _fila(10)
	_alerta.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_alerta.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_alerta.offset_top = 12.0
	_alerta.visible = false
	add_child(_alerta)
	_alerta.add_child(_icono(OJO, PX_CHICO))
	_texto_alerta = _etiqueta("", 18)
	_alerta.add_child(_texto_alerta)
	_alerta.add_child(_icono(OJO, PX_CHICO))

	# Teclas abajo a la izquierda
	_ayuda = _fila(16)
	_ayuda.anchor_top = 1.0
	_ayuda.anchor_bottom = 1.0
	_ayuda.offset_left = 14.0
	_ayuda.offset_top = -38.0
	_ayuda.offset_bottom = -12.0
	_ayuda.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ayuda.modulate.a = 0.8
	_ayuda.visible = false
	add_child(_ayuda)


func _crear_vidas(n: int) -> void:
	for c in _fila_vidas.get_children():
		c.queue_free()
	_iconos_vida.clear()
	for i in n:
		var ic := _icono(VIDA)
		_fila_vidas.add_child(ic)
		_iconos_vida.append(ic)
	_vidas_mostradas = n


# ================= Vidas =================

func _al_cambiar_vidas(v: int) -> void:
	var antes := _vidas_mostradas
	_vidas_mostradas = v
	# Una veladora de más (vida extra cuando ya estaban todas)
	while _jugador and _iconos_vida.size() < int(_jugador.vidas_max):
		var nueva := _icono(VIDA_APAGADA)
		_fila_vidas.add_child(nueva)
		_iconos_vida.append(nueva)
	for i in _iconos_vida.size():
		var ic := _iconos_vida[i]
		if i < v:
			ic.texture = VIDA
			ic.modulate = Color.WHITE
			if i >= antes:
				_encender_veladora(ic)
		elif i < antes:
			_apagar_veladora(ic)
		else:
			ic.texture = VIDA_APAGADA
	if v < antes:
		_veladora_grande()
		_sacudir(_columna)


func _encender_veladora(ic: TextureRect) -> void:
	# Espera un cuadro para que el contenedor le dé tamaño
	await get_tree().process_frame
	_pulso(ic, 1.8)
	_destellos(ic)


func _apagar_veladora(ic: TextureRect) -> void:
	ic.pivot_offset = ic.size * 0.5
	var tw := ic.create_tween()
	tw.tween_property(ic, "modulate", Color(2.2, 2.2, 2.2), 0.08)
	tw.tween_callback(ic.set.bind("texture", VIDA_APAGADA))
	tw.parallel().tween_property(ic, "scale", Vector2(1.35, 1.35), 0.08)
	tw.tween_property(ic, "modulate", Color.WHITE, 0.35)
	tw.parallel().tween_property(ic, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_humo(ic, Vector2(ic.size.x * 0.5, 6.0), 18)


## Una veladora grande que se apaga al centro de la pantalla: perdiste una vida
func _veladora_grande() -> void:
	var v := TextureRect.new()
	v.texture = VIDA
	v.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.scale = Vector2(3, 3)
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	var tam := VIDA.get_size() * PX
	v.size = tam
	v.pivot_offset = tam * 0.5
	v.position = get_viewport_rect().size * 0.5 - tam * 0.5 - Vector2(0, 60)
	add_child(v)
	var tw := v.create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(_apagar_grande.bind(v))
	tw.tween_interval(0.7)
	tw.tween_property(v, "modulate:a", 0.0, 0.6)
	tw.tween_callback(v.queue_free)


func _apagar_grande(v: TextureRect) -> void:
	v.texture = VIDA_APAGADA
	_humo(v, Vector2(v.size.x * 0.5, 4.0), 30)


# ================= Ofrenda =================

## Agrega una pieza de la ofrenda. Busca su ícono en assets/hud/ofrenda_<id>.png
## (o usa "textura"). "icono_vacio" se muestra mientras no la encuentras (ej. "desconocido").
func agregar_ofrenda(id: String, nombre: String, lleno: bool = false, textura: Texture2D = null, icono_vacio: String = "") -> void:
	var tex := _textura_icono("ofrenda_" + id)
	if tex == null:
		tex = textura
	var vacia: Texture2D = _textura_icono(icono_vacio) if icono_vacio != "" else null
	var ranura := PanelContainer.new()
	ranura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ranura.tooltip_text = nombre
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.border_color = Color(0.4, 0.4, 0.4, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(3)
	ranura.add_theme_stylebox_override("panel", sb)
	var centro := CenterContainer.new()
	centro.custom_minimum_size = Vector2(16, 20) * PX
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ranura.add_child(centro)
	var ic := _icono(tex)
	centro.add_child(ic)
	_fila_ofrenda.add_child(ranura)
	_ofrenda[id] = {"icono": ic, "lleno": false, "textura": tex, "vacia": vacia, "ranura": sb}
	_panel_ofrenda.visible = true
	_pintar_ofrenda(id, lleno)


## Cambia el título del panel de la derecha (ej. "R E C U E R D O S" en la cueva)
func titulo_ofrenda(texto: String) -> void:
	_titulo_ofrenda.text = texto


## Las piezas que Xochik ya juntó en niveles anteriores (Juego.ofrenda guarda sus texturas)
func agregar_ofrenda_del_viaje(con_juguete: bool) -> void:
	var tiene := {"vela": false, "flor": false, "petalos": false, "juguete": false}
	for ruta in Juego.ofrenda:
		var archivo: String = ruta.get_file()
		if archivo.contains("petalos"):
			tiene["petalos"] = true
		elif archivo.contains("vela"):
			tiene["vela"] = true
		elif archivo.contains("flor"):
			tiene["flor"] = true
		else:
			tiene["juguete"] = true
	agregar_ofrenda("vela", "Vela", tiene["vela"])
	agregar_ofrenda("flor", "Flor de cempasúchil", tiene["flor"])
	agregar_ofrenda("petalos", "Pétalos", tiene["petalos"])
	if con_juguete:
		agregar_ofrenda("juguete", "El juguete del hijo de la Llorona", tiene["juguete"], null, "desconocido")


## Ilumina una pieza. Si das la posición en el mundo, el ícono "vuela" desde ahí hasta su lugar.
func llenar_ofrenda(id: String, desde_mundo: Variant = null) -> void:
	if not _ofrenda.has(id) or _ofrenda[id]["lleno"]:
		return
	var ic: TextureRect = _ofrenda[id]["icono"]
	if desde_mundo is Vector2:
		var pos_mundo: Vector2 = desde_mundo
		var origen: Vector2 = get_viewport().get_canvas_transform() * pos_mundo
		_volar(_ofrenda[id]["textura"], origen, ic, _pintar_ofrenda.bind(id, true, true))
	else:
		_pintar_ofrenda(id, true, true)


## Cambia la textura de una pieza (ej. la pertenencia verdadera de la Llorona)
func textura_ofrenda(id: String, tex: Texture2D) -> void:
	if _ofrenda.has(id) and tex:
		_ofrenda[id]["textura"] = tex
		_pintar_ofrenda(id, _ofrenda[id]["lleno"])


func ofrenda_completa() -> bool:
	for id in _ofrenda:
		if not _ofrenda[id]["lleno"]:
			return false
	return true


func _pintar_ofrenda(id: String, lleno: bool, festejar: bool = false) -> void:
	var o: Dictionary = _ofrenda[id]
	o["lleno"] = lleno
	var ic: TextureRect = o["icono"]
	var sb: StyleBoxFlat = o["ranura"]
	if lleno:
		_poner_textura(ic, o["textura"], PX)
		ic.modulate = Color.WHITE
		sb.border_color = Color(0.9, 0.9, 0.9, 0.95)
		sb.bg_color = Color(0.18, 0.18, 0.18, 0.6)
	else:
		var vacia: Texture2D = o["vacia"]
		_poner_textura(ic, vacia if vacia else o["textura"], PX)
		# Sin encontrar: solo su silueta oscura
		ic.modulate = Color(0.5, 0.5, 0.5, 0.8) if vacia else Color(0.16, 0.16, 0.16, 0.95)
		sb.border_color = Color(0.4, 0.4, 0.4, 0.8)
		sb.bg_color = Color(0, 0, 0, 0.45)
	if festejar:
		_pulso(ic, 1.6)
		_destellos(ic)
		if ofrenda_completa():
			_pulso(_panel_ofrenda, 1.12)


# ================= Talismanes =================

## Registra un talismán con la tecla de su acción. cantidad = -1 es ilimitado (sin número).
func agregar_talisman(id: String, accion: String, cantidad: int = 0) -> void:
	if _talismanes.has(id):
		return
	var caja := _fila(4)
	var tex := _textura_icono(id)
	if tex == null:
		tex = _textura_icono("ofrenda_" + id)
	var ic := _icono(tex)
	caja.add_child(ic)
	var num := _etiqueta("", 15)
	caja.add_child(num)
	caja.add_child(tecla_visual(nombre_tecla(accion)))
	_fila_talismanes.add_child(caja)
	_fila_talismanes.visible = true
	_separador.visible = true
	_talismanes[id] = {"icono": ic, "cantidad": num, "valor": -999, "caja": caja}
	talisman(id, cantidad)


func talisman(id: String, cantidad: int) -> void:
	if not _talismanes.has(id):
		return
	var t: Dictionary = _talismanes[id]
	var antes: int = t["valor"]
	if antes == cantidad:
		return
	t["valor"] = cantidad
	var num: Label = t["cantidad"]
	num.text = "" if cantidad < 0 else "×%d" % cantidad
	var caja: HBoxContainer = t["caja"]
	caja.modulate = Color(0.38, 0.38, 0.38, 0.85) if cantidad == 0 else Color.WHITE
	if antes != -999 and cantidad > antes:
		_pulso(t["icono"], 1.6)
		_destellos(t["icono"])


## Destello al usar un talismán
func usar(id: String) -> void:
	if _talismanes.has(id):
		_pulso(_talismanes[id]["icono"], 0.75)


# ================= Luz de Chicomexochitl =================

func mostrar_luz() -> void:
	_fila_luz.visible = true
	if _icono_luz:
		return
	_icono_luz = _icono(LLAMA, PX)
	_icono_luz.custom_minimum_size = Vector2(14, 13) * PX
	_icono_luz.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fila_luz.add_child(_icono_luz)
	_barra = BarraLuz.new()
	_barra.custom_minimum_size = Vector2(150, 14)
	_barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fila_luz.add_child(_barra)
	_fila_luz.add_child(tecla_visual(nombre_tecla("ocultar_luz")))


func luz(valor: float, maximo: float, agotada: bool, oculta: bool) -> void:
	if _barra == null:
		return
	_barra.fraccion = clampf(valor / maxf(maximo, 0.001), 0.0, 1.0)
	_barra.agotada = agotada
	_barra.oculta = oculta
	_barra.queue_redraw()
	_icono_luz.texture = LUZ_OCULTA if oculta else LLAMA
	var f: float = 1.0 if oculta else 0.85 + 0.15 * sin(_t * 9.0) * sin(_t * 2.3)
	var g: float = 0.4 if agotada and not oculta else 1.0
	_icono_luz.modulate = Color(f * g, f * g, f * g)
	estado("luz_oculta", oculta)


# ================= En la mano (nivel del río) =================

func en_mano(tex: Texture2D, nombre: String) -> void:
	if _textura_mano == null:
		_fila_mano.add_child(_icono(MANO, PX_CHICO))
		_textura_mano = TextureRect.new()
		_textura_mano.custom_minimum_size = Vector2(34, 34)
		_textura_mano.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_textura_mano.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_textura_mano.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fila_mano.add_child(_textura_mano)
		_nombre_mano = _etiqueta("", 15)
		_fila_mano.add_child(_nombre_mano)
	var cambio := _textura_mano.texture != tex
	_fila_mano.visible = tex != null
	_textura_mano.texture = tex
	_nombre_mano.text = nombre
	if cambio and tex != null:
		_pulso(_textura_mano, 1.4)


# ================= Estados, objetivo, alerta, ayuda =================

func estado(id: String, activo: bool) -> void:
	if not activo and not _estados.has(id):
		return
	if not _estados.has(id):
		var datos: Array = ESTADOS.get(id, [id, id])
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.6)
		sb.border_color = Color(0.7, 0.7, 0.7, 0.7)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 6
		sb.content_margin_right = 10
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		chip.add_theme_stylebox_override("panel", sb)
		var fila := _fila(6)
		chip.add_child(fila)
		var ic := _icono(_textura_icono(datos[0]), PX_CHICO)
		fila.add_child(ic)
		fila.add_child(_etiqueta(datos[1], 13))
		chip.visible = false
		_fila_estados.add_child(chip)
		_estados[id] = chip
	var c: PanelContainer = _estados[id]
	if c.visible != activo:
		c.visible = activo
		if activo:
			c.modulate.a = 0.0
			c.create_tween().tween_property(c, "modulate:a", 1.0, 0.2)


func objetivo(texto: String) -> void:
	_objetivo.text = texto
	_objetivo.visible = texto != ""


func alerta(texto: String, activa: bool) -> void:
	_texto_alerta.text = texto
	if activa and not _alerta.visible:
		_alerta.visible = true
		_pulso(_alerta, 1.25)
	elif not activa:
		_alerta.visible = false


## lista = [ [["izquierda", "derecha"], "Moverse"], [["saltar"], "Saltar"], ... ]
func ayuda(lista: Array) -> void:
	for c in _ayuda.get_children():
		c.queue_free()
	for par in lista:
		var grupo := _fila(3)
		for accion in par[0]:
			grupo.add_child(tecla_visual(nombre_tecla(accion), 12))
		var l := _etiqueta(" " + str(par[1]), 13)
		grupo.add_child(l)
		_ayuda.add_child(grupo)
	_ayuda.visible = not lista.is_empty()


# ================= Piezas visuales =================

func _panel_bordado() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxTexture.new()
	sb.texture = MARCO
	sb.texture_margin_left = 10
	sb.texture_margin_right = 10
	sb.texture_margin_top = 10
	sb.texture_margin_bottom = 10
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	p.add_theme_stylebox_override("panel", sb)
	return p


func _fila(separacion: int) -> HBoxContainer:
	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", separacion)
	f.alignment = BoxContainer.ALIGNMENT_BEGIN
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


func _icono(tex: Texture2D, px: int = PX) -> TextureRect:
	var r := TextureRect.new()
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	_poner_textura(r, tex, px)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _etiqueta(texto: String, tam: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color(0.93, 0.93, 0.93))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Una tecla dibujada como tecla de teclado
func tecla_visual(texto: String, tam: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.12, 0.95)
	sb.border_color = Color(0.8, 0.8, 0.8)
	sb.set_border_width_all(1)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 0
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", Color.WHITE)
	p.add_child(l)
	return p


## Nombre corto de la primera tecla de una acción del Mapa de Entrada
static func nombre_tecla(accion: String) -> String:
	if not InputMap.has_action(accion):
		return accion
	for ev in InputMap.action_get_events(accion):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			var codigo: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			var n := OS.get_keycode_string(codigo)
			match n:
				"Space": return "Espacio"
				"Left": return "←"
				"Right": return "→"
				"Up": return "↑"
				"Down": return "↓"
				"Escape": return "Esc"
			return n
	return "?"


## Cambia la textura y ajusta el tamaño a un múltiplo exacto (pixel art nítido)
func _poner_textura(r: TextureRect, tex: Texture2D, px: int) -> void:
	r.texture = tex
	r.custom_minimum_size = tex.get_size() * px if tex else Vector2.ZERO


func _textura_icono(nombre: String) -> Texture2D:
	var ruta := RUTA_ICONO % nombre
	if nombre != "" and ResourceLoader.exists(ruta):
		return load(ruta) as Texture2D
	return null


# ================= Animaciones =================

func _pulso(nodo: Control, escala: float) -> void:
	nodo.pivot_offset = nodo.size * 0.5
	nodo.scale = Vector2(escala, escala)
	var tw := nodo.create_tween()
	tw.tween_property(nodo, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _sacudir(nodo: Control) -> void:
	var base := Vector2(12, 10)
	var tw := nodo.create_tween()
	for i in 6:
		var lado := 1.0 if i % 2 == 0 else -1.0
		tw.tween_property(nodo, "position", base + Vector2(lado * (6 - i), 0), 0.04)
	tw.tween_property(nodo, "position", base, 0.04)


func _volar(tex: Texture2D, desde: Vector2, destino: Control, al_llegar: Callable) -> void:
	var v := TextureRect.new()
	v.texture = tex
	v.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.size = tex.get_size() * PX if tex else Vector2(48, 60)
	v.pivot_offset = v.size * 0.5
	v.position = desde - v.size * 0.5
	v.scale = Vector2(1.8, 1.8)
	add_child(v)
	var meta := destino.get_global_rect().get_center() - v.size * 0.5
	var medio := (v.position + meta) * 0.5 + Vector2(0, -90)
	var tw := v.create_tween()
	tw.tween_method(_mover_curva.bind(v, v.position, medio, meta), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(v, "scale", Vector2.ONE, 0.7)
	tw.tween_callback(v.queue_free)
	tw.tween_callback(al_llegar)


func _mover_curva(t: float, nodo: Control, a: Vector2, b: Vector2, c: Vector2) -> void:
	nodo.position = a.lerp(b, t).lerp(b.lerp(c, t), t)


func _destellos(nodo: Control) -> void:
	var p := CPUParticles2D.new()
	p.position = nodo.size * 0.5
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 14
	p.lifetime = 0.6
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.damping_min = 60.0
	p.damping_max = 90.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	nodo.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func _humo(nodo: Control, pos: Vector2, cantidad: int) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.5
	p.amount = cantidad
	p.lifetime = 1.1
	p.direction = Vector2.UP
	p.spread = 25.0
	p.gravity = Vector2(0, -30)
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 35.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	var g := Gradient.new()
	g.set_color(0, Color(0.8, 0.8, 0.8, 0.8))
	g.set_color(1, Color(0.5, 0.5, 0.5, 0))
	p.color_ramp = g
	nodo.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)


## Barra de luz: cera en segmentos; el último tiembla como flama
class BarraLuz extends Control:
	var fraccion := 1.0
	var agotada := false
	var oculta := false
	const SEGMENTOS := 16

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(0, 0, w, h), Color(0.75, 0.75, 0.75, 0.8), false, 1.0)
		var hueco := 2.0
		var ancho := (w - 4.0 - hueco * (SEGMENTOS - 1)) / SEGMENTOS
		var llenos := fraccion * SEGMENTOS
		var t := Time.get_ticks_msec() / 1000.0
		for i in SEGMENTOS:
			var x := 2.0 + i * (ancho + hueco)
			var r := Rect2(x, 2.0, ancho, h - 4.0)
			var v := 0.0
			if i < floor(llenos):
				v = lerpf(0.55, 0.95, float(i) / SEGMENTOS)
			elif i < llenos:
				v = (llenos - i) * (0.7 + 0.3 * sin(t * 14.0))
			if v <= 0.0:
				draw_rect(r, Color(0.13, 0.13, 0.13))
				continue
			if oculta:
				v *= 0.45
			elif agotada:
				v *= 0.35 + 0.25 * absf(sin(t * 6.0))
			draw_rect(r, Color(v, v, v))
			draw_rect(Rect2(x, 2.0, ancho, 2.0), Color(minf(v + 0.15, 1.0), minf(v + 0.15, 1.0), minf(v + 0.15, 1.0)))
