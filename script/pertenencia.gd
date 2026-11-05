@tool
extends Area2D
class_name Pertenencia
## Pertenencia de los hijos de la Llorona (nivel 2).
## Solo una debe tener "es_correcto" activado; las demás son señuelos.
## Xochik carga una a la vez: si toma otra, la anterior regresa a su lugar.

signal tomada(obj: Pertenencia)

@export var nombre: String = "Trompo"
@export var es_correcto: bool = false
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

@onready var sprite: Sprite2D = $Sprite2D
@onready var aviso: Label = $Aviso

var _jugador_cerca := false
var _cargada := false
var _t := 0.0


func _ready() -> void:
	sprite.texture = textura
	sprite.scale = Vector2.ONE * escala
	if Engine.is_editor_hint():
		return
	add_to_group("pertenencias")
	aviso.text = "[E] Tomar " + nombre
	_t = randf() * TAU
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(b: Node) -> void:
	if b.is_in_group("jugador"):
		_jugador_cerca = true
		aviso.visible = not _cargada


func _on_body_exited(b: Node) -> void:
	if b.is_in_group("jugador"):
		_jugador_cerca = false
		aviso.visible = false


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _cargada:
		return
	_t += delta
	sprite.position.y = sin(_t * 2.0) * 3.0
	var brillo := 0.85 + sin(_t * 3.0) * 0.15
	sprite.modulate = Color(brillo, brillo, brillo)
	var jugador = get_tree().get_first_node_in_group("jugador")
	if _jugador_cerca and jugador and not jugador.atrapada and Input.is_action_just_pressed("interactuar"):
		tomar(jugador)


func tomar(jugador: Node) -> void:
	if jugador.objeto_en_mano and jugador.objeto_en_mano != self:
		jugador.objeto_en_mano.devolver()
	jugador.objeto_en_mano = self
	jugador.mostrar_en_mano(textura)
	_cargada = true
	aviso.visible = false
	hide()
	set_deferred("monitoring", false)
	tomada.emit(self)


## Regresa a su lugar original (al cambiarla por otra o al fallar la entrega)
func devolver() -> void:
	_cargada = false
	_jugador_cerca = false
	sprite.modulate = Color(1, 1, 1, 0)
	show()
	set_deferred("monitoring", true)
	create_tween().tween_property(sprite, "modulate:a", 1.0, 0.6)
