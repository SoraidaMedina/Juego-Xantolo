extends Area2D
## Zona de agua: si Xochik cae, pierde una vida y reaparece en el punto de control.
## Ajusta el rectángulo para que cubra toda el agua.

func _ready() -> void:
	body_entered.connect(_al_caer)


func _al_caer(cuerpo: Node) -> void:
	if cuerpo.is_in_group("jugador") and cuerpo.has_method("ser_atrapada"):
		cuerpo.ser_atrapada("¡Caíste al agua!")
