extends Area2D
## Meta del nivel. Si "es_entrada" está activo, Xochik camina hacia el centro
## (el hueco de la montaña), se hace pequeña y desaparece en la oscuridad.

signal alcanzada

## Xochik "entra" al hueco en lugar de solo tocar la meta
@export var es_entrada: bool = true

var _hecho := false

func _ready() -> void:
	add_to_group("meta")
	body_entered.connect(_al_entrar)


func _al_entrar(b: Node) -> void:
	if _hecho or not b.is_in_group("jugador"):
		return
	_hecho = true
	if es_entrada:
		b.atrapada = true          # ya no se puede mover
		b.velocity = Vector2.ZERO
		var anim: AnimatedSprite2D = b.get_node("AnimatedSprite2D")
		anim.flip_h = global_position.x < b.global_position.x
		anim.play("walk")
		var tw := create_tween().set_parallel(true)
		tw.tween_property(b, "global_position:x", global_position.x, 1.2)
		tw.tween_property(anim, "modulate", Color(0, 0, 0, 0), 1.2).set_delay(0.3)
		tw.tween_property(anim, "scale", anim.scale * 0.85, 1.2)
		await tw.finished
	alcanzada.emit()
