@tool
extends Area2D
class_name ObjetoOfrenda
## Objeto recolectable del nivel: velas y flores de la ofrenda, o talismanes (copal, pétalos).
## Arrastra objeto_ofrenda.tscn al nivel, elige "tipo" y "textura" en el Inspector y listo.

signal recogido(objeto: ObjetoOfrenda)

@export_enum("vela", "flor", "copal", "petalos", "papel_picado", "amuleto", "veladora", "recuerdo") var tipo: String = "vela"
@export var textura: Texture2D:
	set(valor):
		textura = valor
		if is_node_ready():
			$Sprite2D.texture = valor
@export var escala: float = 0.12:
	set(valor):
		escala = valor
		if is_node_ready():
			$Sprite2D.scale = Vector2.ONE * valor
@export var recoger_automatico: bool = false
## Radio de ruido al recoger (alerta a chaneques cercanos). 0 = silencioso.
@export var ruido_al_recoger: float = 0.0
## Solo copal: vuelve a aparecer en su lugar cuando se usa
@export var reaparece: bool = true
## Escondido por las ánimas: no se ve ni se puede tomar hasta que el humo del copal
## o los pétalos de cempasúchil lo revelan. Mientras, solo brillan unas motas tenues.
@export_enum("no", "copal", "petalos") var oculto_hasta: String = "no"
## Solo objetos con memoria (tipo "recuerdo"): cuál es ("balero", "foto", "vela") y qué dice el aviso
@export var id_recuerdo: String = ""
@export var nombre_aviso: String = ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var aviso: Label = $Aviso

const NOMBRES := {
	"vela": "Vela de la ofrenda",
	"flor": "Flor de cempasúchil",
	"copal": "Copal",
	"petalos": "Pétalos de cempasúchil",
	"papel_picado": "Papel picado",
	"amuleto": "Amuleto bordado",
	"veladora": "Veladora de las ánimas",
	"recuerdo": "Recuerdo",
}

var _halo: Sprite2D
var _jugador_cerca := false
var _recogido := false
var _t := 0.0
var _oculto := false
var _motas: CPUParticles2D


func _ready() -> void:
	sprite.texture = textura
	sprite.scale = Vector2.ONE * escala
	if Engine.is_editor_hint():
		return
	add_to_group("recolectable")
	aviso.text = "[E] " + (nombre_aviso if nombre_aviso != "" else NOMBRES.get(tipo, "Recoger"))
	_crear_halo()
	_t = randf() * TAU  # para que no floten todos sincronizados
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if oculto_hasta != "no":
		_esconder()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _recogido or _oculto:
		return
	_t += delta
	# Flota y brilla suave para que se distinga en la penumbra
	sprite.position.y = sin(_t * 2.0) * 3.0
	var brillo := 0.85 + sin(_t * 3.0) * 0.15
	sprite.modulate = Color(brillo, brillo, brillo, sprite.modulate.a)
	if _halo:
		_halo.modulate.a = 0.25 + sin(_t * 3.0) * 0.12
	var jugador = get_tree().get_first_node_in_group("jugador")
	if jugador and jugador.get("atrapada"):
		return
	if _jugador_cerca and Input.is_action_just_pressed("interactuar"):
		recoger()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("jugador"):
		return
	if recoger_automatico:
		recoger()
	else:
		_jugador_cerca = true
		aviso.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("jugador"):
		_jugador_cerca = false
		aviso.visible = false


func recoger() -> void:
	if _recogido:
		return
	_recogido = true
	aviso.visible = false
	set_deferred("monitoring", false)
	recogido.emit(self)
	if tipo in ["vela", "flor", "petalos"] and textura:
		Juego.agregar_ofrenda(textura.resource_path)
	Juego.sfx("recoger", -2.0)

	if ruido_al_recoger > 0.0:
		for c in get_tree().get_nodes_in_group("chaneques"):
			if c.has_method("escuchar_ruido") and c.global_position.distance_to(global_position) <= ruido_al_recoger:
				c.escuchar_ruido(global_position)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(sprite, "position:y", sprite.position.y - 24.0, 0.4)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.4)
	if reaparece and tipo == "copal":
		tw.chain().tween_callback(hide)
	else:
		tw.chain().tween_callback(queue_free)


func _esconder() -> void:
	_oculto = true
	add_to_group("oculto_" + oculto_hasta)
	sprite.modulate.a = 0.0
	set_deferred("monitoring", false)
	# Pista: motas de luz muy tenues donde está escondido
	_motas = CPUParticles2D.new()
	_motas.amount = 6
	_motas.lifetime = 2.5
	_motas.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_motas.emission_sphere_radius = 22.0
	_motas.gravity = Vector2(0, -6)
	_motas.initial_velocity_min = 2.0
	_motas.initial_velocity_max = 6.0
	_motas.scale_amount_min = 1.5
	_motas.scale_amount_max = 2.5
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.add_point(0.5, Color(1, 1, 1, 0.35))
	g.set_color(1, Color(1, 1, 1, 0.0))
	_motas.color_ramp = g
	add_child(_motas)


## La llaman el copal o los pétalos: el objeto aparece entre destellos
func revelar() -> void:
	if not _oculto:
		return
	_oculto = false
	remove_from_group("oculto_" + oculto_hasta)
	set_deferred("monitoring", true)
	if _motas:
		_motas.emitting = false
		get_tree().create_timer(3.0, false).timeout.connect(_motas.queue_free)
	var destello := CPUParticles2D.new()
	destello.one_shot = true
	destello.explosiveness = 0.85
	destello.amount = 24
	destello.lifetime = 0.9
	destello.spread = 180.0
	destello.gravity = Vector2(0, -20)
	destello.initial_velocity_min = 30.0
	destello.initial_velocity_max = 80.0
	destello.damping_min = 40.0
	destello.damping_max = 60.0
	destello.scale_amount_min = 2.0
	destello.scale_amount_max = 3.5
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	destello.color_ramp = g
	add_child(destello)
	destello.emitting = true
	get_tree().create_timer(1.5, false).timeout.connect(destello.queue_free)
	Juego.sfx("vela", -4.0, 1.3)
	create_tween().tween_property(sprite, "modulate:a", 1.0, 0.8)


## La llama el nivel cuando el talismán se usa: vuelve a su lugar
func reaparecer() -> void:
	_recogido = false
	_jugador_cerca = false
	sprite.position.y = 0.0
	sprite.modulate = Color(1, 1, 1, 0)
	show()
	set_deferred("monitoring", true)
	create_tween().tween_property(sprite, "modulate:a", 1.0, 0.6)


## Resplandor suave detrás del objeto: en escala de grises, pero se distingue en la penumbra
func _crear_halo() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.9))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 96
	tex.height = 96
	_halo = Sprite2D.new()
	_halo.texture = tex
	_halo.show_behind_parent = true
	_halo.modulate.a = 0.3
	sprite.add_child(_halo)
	_halo.scale = Vector2.ONE / maxf(escala, 0.01)
