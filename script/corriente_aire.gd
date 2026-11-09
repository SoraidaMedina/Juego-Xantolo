extends Area2D
## Corriente de aire de la cueva. Cada tanto silba (aviso) y luego sopla una ráfaga.
## Si Xochik está DE PIE dentro de la ráfaga, el viento apaga la llama de Chicomexochitl.
## Agachada [S] la cubre con su cuerpo y la llama sobrevive.
## Pon el nodo en el centro de la zona; "tamano" es el área que cubre.

@export var tamano: Vector2 = Vector2(400, 300)
@export var calma_min: float = 3.5
@export var calma_max: float = 6.0
## Segundos de silbido antes de que sople (para alcanzar a agacharse)
@export var aviso: float = 1.3
@export var duracion: float = 2.0
## -1 sopla hacia la izquierda, 1 hacia la derecha
@export var direccion: float = -1.0
## Segundos de desfase al empezar (para que dos corrientes no soplen juntas)
@export var desfase: float = 0.0

var estado := "calma"
var _t := 0.0
var _jugador: Node = null
var _polvo_suave: CPUParticles2D
var _polvo_fuerte: CPUParticles2D


func _ready() -> void:
	add_to_group("corrientes")
	var forma := RectangleShape2D.new()
	forma.size = tamano
	var cs := CollisionShape2D.new()
	cs.shape = forma
	add_child(cs)
	body_entered.connect(_al_entrar)
	body_exited.connect(_al_salir)
	_polvo_suave = _crear_polvo(10, 25.0, 0.35)
	_polvo_suave.emitting = true
	_polvo_fuerte = _crear_polvo(60, 420.0, 0.75)
	_polvo_fuerte.emitting = false
	_t = randf_range(calma_min, calma_max) + desfase


func _crear_polvo(cantidad: int, velocidad: float, alfa: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = cantidad
	p.lifetime = tamano.x / maxf(velocidad, 1.0) * 1.1
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(6, tamano.y * 0.45)
	p.position = Vector2(-direccion * tamano.x * 0.5, 0)
	p.direction = Vector2(direccion, -0.05)
	p.spread = 6.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = velocidad * 0.7
	p.initial_velocity_max = velocidad
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.85, 0.85, 0.0))
	g.add_point(0.15, Color(0.85, 0.85, 0.85, alfa))
	g.set_color(1, Color(0.85, 0.85, 0.85, 0.0))
	p.color_ramp = g
	add_child(p)
	return p


func _physics_process(delta: float) -> void:
	var nivel := get_tree().get_first_node_in_group("nivel")
	if nivel and nivel.has_method("corrientes_activas") and not nivel.corrientes_activas():
		return
	_t -= delta
	match estado:
		"calma":
			if _t <= 0.0:
				estado = "aviso"
				_t = aviso
				_polvo_fuerte.speed_scale = 0.35
				_polvo_fuerte.emitting = true
				if _jugador_cerca():
					Juego.sfx("viento", -3.0, randf_range(0.95, 1.05))
		"aviso":
			if _t <= 0.0:
				estado = "rafaga"
				_t = duracion
				_polvo_fuerte.speed_scale = 1.0
		"rafaga":
			if _jugador and not _jugador.agachada and not _jugador.atrapada and nivel and nivel.has_method("apagar_luz"):
				nivel.apagar_luz()
			if _t <= 0.0:
				estado = "calma"
				_t = randf_range(calma_min, calma_max)
				_polvo_fuerte.emitting = false


## El silbido se oye solo si Xochik está en la misma pantalla
func _jugador_cerca() -> bool:
	var j := get_tree().get_first_node_in_group("jugador") as Node2D
	return j != null and absf(j.global_position.x - global_position.x) < 900.0


func soplando() -> bool:
	return estado == "rafaga"


func _al_entrar(b: Node) -> void:
	if b.is_in_group("jugador"):
		_jugador = b


func _al_salir(b: Node) -> void:
	if b == _jugador:
		_jugador = null
