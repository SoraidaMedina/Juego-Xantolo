extends Area2D
## Zona donde Xochik puede esconderse AGACHADA (arbustos, rocas, juncos).
## Ajusta el tamaño con el CollisionShape2D.
## Cuando Xochik entra, aparece una pista discreta para que sepa que ahí puede ocultarse.

@export var mostrar_pista: bool = true
@export var texto_pista: String = "[S] Esconderse"

var _jugador: Node = null
var _pista: Label


func _ready() -> void:
	body_entered.connect(_al_entrar)
	body_exited.connect(_al_salir)
	_pista = Label.new()
	_pista.text = texto_pista
	_pista.add_theme_font_size_override("font_size", 13)
	_pista.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_pista.add_theme_color_override("font_outline_color", Color.BLACK)
	_pista.add_theme_constant_override("outline_size", 4)
	_pista.position = Vector2(-48, -70)
	_pista.modulate.a = 0.0
	add_child(_pista)


func _process(delta: float) -> void:
	var ver := 0.0
	if mostrar_pista and _jugador and not _jugador.esta_escondida():
		ver = 0.85
	_pista.modulate.a = move_toward(_pista.modulate.a, ver, delta * 4.0)


func _al_entrar(b: Node) -> void:
	if b.is_in_group("jugador"):
		b.en_escondite = true
		Juego.sfx("escondite", -6.0)
		_jugador = b


func _al_salir(b: Node) -> void:
	if b.is_in_group("jugador"):
		b.en_escondite = false
		_jugador = null
