extends Area2D
## Zona donde Xochik puede esconderse AGACHADA (arbustos, rocas, juncos).
## Ajusta el tamaño con el CollisionShape2D.

func _ready() -> void:
	body_entered.connect(_al_entrar)
	body_exited.connect(_al_salir)


func _al_entrar(b: Node) -> void:
	if b.is_in_group("jugador"):
		b.en_escondite = true


func _al_salir(b: Node) -> void:
	if b.is_in_group("jugador"):
		b.en_escondite = false
