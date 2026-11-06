extends CharacterBody2D
## Chaneque — presencia traviesa de la Sierra (nivel 1), según el documento técnico:
## · Siempre está presente patrullando (solo se esfuma con el copal o después de atraparte).
## · Es curioso: si una piedrita [R] cae cerca, va a investigar el ruido y deja libre el paso.
## · Reacciona al RUIDO: caminar normal hace ruido, saltar o caer hace MUCHO ruido.
##   Agachada (quieta o caminando despacio) = silencio.
## · REGLA: "si no te oye, no te ve". Agachada y en silencio puedes pasar junto a él.
##   El anillo alrededor de Xochik marca hasta dónde se oyen sus pasos (= rango_oido).
## · Cuando la sospecha se llena ríe, avisa a los cercanos (atacan en grupo) y corre hacia ti.
## · Escondida en un arbusto o quemando copal [Q] estás a salvo.
## · Ya no quita vida con solo tocarte: primero tiene que descubrirte.

@export var velocidad: float = 55.0
@export var velocidad_persecucion: float = 135.0
@export var distancia_patrulla: float = 160.0
## Distancia a la que oye pasos normales (saltar la multiplica x1.6)
@export var rango_oido: float = 190.0
## Segundos de ruido continuo antes de descubrirte
@export var tiempo_para_detectar: float = 1.5
## Segundos que te persigue antes de rendirse
@export var tiempo_persecucion: float = 3.0
@export var rango_contacto: float = 42.0
## Segundos fuera después del copal
@export var tiempo_dispersado: float = 6.0
## Si está activo, se esfuma solo de vez en cuando (ciclo de aparecer / desaparecer)
@export var desaparece_solo: bool = false
## Distancia a la que oye caer una piedrita y va a investigar
@export var rango_distraccion: float = 420.0
## Segundos que se queda buscando donde cayó la piedrita
@export var tiempo_investigando: float = 3.5
@export var tiempo_visible_min: float = 6.0
@export var tiempo_visible_max: float = 10.0
@export var tiempo_oculto_min: float = 2.0
@export var tiempo_oculto_max: float = 3.5
## Radio en el que avisa a otros chaneques cuando te descubre
@export var rango_grupo: float = 450.0
## Qué tan rápido sube la sospecha si estás quieta, a la vista y muy cerca (0 = nunca)
@export var factor_quieta: float = 0.0

var gravedad: float = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var inicio_x: float
var dir: float = 1.0
## patrulla | alerta | investiga | persigue | riendo | oculto | dispersado
var estado: String = "patrulla"
var sospecha: float = 0.0
var _t: float = 0.0
var _t_persecucion: float = 0.0
var _gen: int = 0            # invalida esperas viejas si cambia de estado
var _icono: Label
var _destino_x: float = 0.0
var _t_busca: float = 0.0


func _ready() -> void:
	add_to_group("chaneques")
	inicio_x = global_position.x
	dir = 1.0 if randf() < 0.5 else -1.0
	_t = randf_range(tiempo_visible_min, tiempo_visible_max)
	_icono = Label.new()
	_icono.add_theme_font_size_override("font_size", 22)
	_icono.add_theme_color_override("font_outline_color", Color.BLACK)
	_icono.add_theme_constant_override("outline_size", 6)
	_icono.position = Vector2(-6, -84)
	_icono.visible = false
	add_child(_icono)
	# Atraviesa a Xochik: solo la daña si la descubrió
	await get_tree().process_frame
	var j := get_tree().get_first_node_in_group("jugador") as PhysicsBody2D
	if j:
		add_collision_exception_with(j)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravedad * delta
	var j := get_tree().get_first_node_in_group("jugador") as CharacterBody2D
	var activo := _nivel_activo()
	_t -= delta

	match estado:
		"patrulla":
			_patrullar()
			if activo:
				_escuchar(j, delta)
			if desaparece_solo and estado == "patrulla" and _t <= 0.0 and sospecha <= 0.0:
				_desvanecer(randf_range(tiempo_oculto_min, tiempo_oculto_max), "oculto")
		"alerta":
			velocity.x = 0.0
			_escuchar(j, delta)
		"investiga":
			_investigar(delta)
			if activo and estado == "investiga":
				_escuchar(j, delta)
		"persigue":
			_perseguir(j, delta)
		_:
			velocity.x = 0.0

	move_and_slide()


func _nivel_activo() -> bool:
	var nivel = get_tree().get_first_node_in_group("nivel")
	return nivel == null or nivel.get("_jugando") != false


func _patrullar() -> void:
	anim.speed_scale = 1.0
	velocity.x = dir * velocidad
	if global_position.x > inicio_x + distancia_patrulla:
		dir = -1.0
	elif global_position.x < inicio_x - distancia_patrulla:
		dir = 1.0
	elif is_on_wall():
		dir = -dir
	anim.flip_h = dir < 0
	_play("walk")


# ---------- Oído ----------

func _escuchar(j: CharacterBody2D, delta: float) -> void:
	if j == null or j.atrapada or j.esta_escondida():
		_bajar_sospecha(delta)
		return
	var nivel = get_tree().get_first_node_in_group("nivel")
	if nivel and nivel.has_method("misma_pantalla") and not nivel.misma_pantalla(global_position):
		_bajar_sospecha(delta)   # no oye lo que pasa en otra pantalla
		return
	var dist := global_position.distance_to(j.global_position)
	var ruido: float = j.nivel_ruido() if j.has_method("nivel_ruido") else (1.0 if absf(j.velocity.x) > 10.0 else 0.0)
	var sube := 0.0
	if ruido > 0.0 and dist < rango_oido * ruido:
		sube = 1.0
	elif dist < rango_oido * 0.45:
		sube = factor_quieta   # quieta, pero demasiado cerca y a la vista

	if sube <= 0.0:
		_bajar_sospecha(delta)
		return
	sospecha += delta * sube
	if estado == "patrulla" or estado == "investiga":
		estado = "alerta"
		Juego.sfx("risa_chaneque", -14.0)
	anim.flip_h = j.global_position.x < global_position.x
	_play("cry")
	_mostrar_icono("?", Color(0.85, 0.85, 0.85))
	_icono.modulate.a = 0.4 + 0.6 * clampf(sospecha / tiempo_para_detectar, 0.0, 1.0)
	if sospecha >= tiempo_para_detectar:
		_descubrir(j, true)


func _bajar_sospecha(delta: float) -> void:
	sospecha = maxf(sospecha - delta * 1.0, 0.0)
	if estado == "alerta":
		_icono.modulate.a = 0.4 + 0.6 * clampf(sospecha / tiempo_para_detectar, 0.0, 1.0)
		if sospecha == 0.0:
			estado = "patrulla"
			_icono.visible = false


## Lo llaman los objetos al recogerse (si tienen ruido_al_recoger > 0)
func escuchar_ruido(pos: Vector2) -> void:
	if estado != "patrulla" and estado != "alerta":
		return
	estado = "alerta"
	sospecha += tiempo_para_detectar * 0.4
	_mostrar_icono("?", Color(0.85, 0.85, 0.85))
	anim.flip_h = pos.x < global_position.x
	_play("cry")


## Una piedrita cayó en pos: si la oye, va a ver qué fue
func distraer(pos: Vector2) -> void:
	if not (estado in ["patrulla", "alerta", "investiga"]):
		return
	if global_position.distance_to(pos) > rango_distraccion:
		return
	estado = "investiga"
	sospecha = 0.0
	_destino_x = pos.x
	_t_busca = tiempo_investigando
	_mostrar_icono("?", Color(0.85, 0.85, 0.85))
	_icono.modulate.a = 1.0


func _investigar(delta: float) -> void:
	var dx := _destino_x - global_position.x
	if absf(dx) > 12.0 and not is_on_wall():
		dir = signf(dx)
		velocity.x = dir * velocidad * 1.7
		anim.flip_h = dir < 0
		anim.speed_scale = 1.4
		_play("walk")
		return
	# Llegó (o algo le estorba): busca mirando a los lados
	velocity.x = 0.0
	anim.speed_scale = 1.0
	_play("cry")
	_t_busca -= delta
	anim.flip_h = int(_t_busca * 1.5) % 2 == 0
	if _t_busca <= 0.0:
		estado = "patrulla"
		_icono.visible = false


# ---------- Persecución ----------

func _descubrir(j: CharacterBody2D, avisar: bool) -> void:
	estado = "persigue"
	sospecha = 0.0
	_t_persecucion = tiempo_persecucion
	_mostrar_icono("!", Color.WHITE)
	_play("cry")
	if avisar:
		Juego.sfx("descubierta")
		Juego.sfx("risa_chaneque")
		# Atacan en grupo: los que están cerca también vienen
		for c in get_tree().get_nodes_in_group("chaneques"):
			if c != self and c.has_method("unirse") and c.global_position.distance_to(global_position) <= rango_grupo:
				c.unirse(j)


## Otro chaneque descubrió a Xochik y llama a este
func unirse(j: CharacterBody2D) -> void:
	if estado in ["patrulla", "alerta", "investiga"]:
		_descubrir(j, false)


func _perseguir(j: CharacterBody2D, delta: float) -> void:
	_t_persecucion -= delta
	if j == null or j.atrapada:
		_calmarse()
		return
	if j.esta_escondida():
		# La perdió de vista: se queda olfateando
		estado = "alerta"
		sospecha = tiempo_para_detectar * 0.5
		_mostrar_icono("?", Color(0.85, 0.85, 0.85))
		return
	var dx := j.global_position.x - global_position.x
	var dy := absf(j.global_position.y - global_position.y)
	dir = signf(dx) if dx != 0.0 else dir
	velocity.x = dir * velocidad_persecucion
	anim.flip_h = dir < 0
	anim.speed_scale = 1.8
	_play("walk")
	if absf(dx) < rango_contacto and dy < 90.0:
		_atrapar(j)
	elif _t_persecucion <= 0.0:
		_calmarse()


func _calmarse() -> void:
	estado = "patrulla"
	sospecha = 0.0
	anim.speed_scale = 1.0
	_icono.visible = false


func _atrapar(j: CharacterBody2D) -> void:
	estado = "riendo"
	velocity.x = 0.0
	anim.speed_scale = 1.0
	_mostrar_icono("!", Color.WHITE)
	_play("cry")
	j.ser_atrapada("Los chaneques te atraparon")
	var gen := _gen
	await get_tree().create_timer(1.2, false).timeout
	if gen == _gen and estado == "riendo":
		# Se esfuma riendo y reaparece en su zona
		_desvanecer(randf_range(tiempo_oculto_min, tiempo_oculto_max) + 1.0, "oculto")


# ---------- Aparecer / desaparecer ----------

## Lo llama el nivel cuando Xochik usa copal [Q]
func dispersar() -> void:
	if estado == "oculto" or estado == "dispersado":
		return
	_desvanecer(tiempo_dispersado, "dispersado")


func _desvanecer(espera: float, nuevo_estado: String) -> void:
	_gen += 1
	var gen := _gen
	estado = nuevo_estado
	sospecha = 0.0
	velocity.x = 0.0
	anim.speed_scale = 1.0
	_icono.visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	_play("disappear")
	if _visible_en_pantalla():
		Juego.sfx("risa_chaneque", -18.0)
	var fuera := create_tween()
	fuera.tween_property(anim, "modulate:a", 0.0, 0.6)
	await fuera.finished
	await get_tree().create_timer(espera, false).timeout
	if gen != _gen:
		return
	_elegir_punto_aparicion()
	$CollisionShape2D.set_deferred("disabled", false)
	_play("idle")
	var dentro := create_tween()
	dentro.tween_property(anim, "modulate:a", 1.0, 0.8)
	await dentro.finished
	if gen != _gen:
		return
	estado = "patrulla"
	_t = randf_range(tiempo_visible_min, tiempo_visible_max)


## Reaparece en otro punto de su zona, pero nunca encima de Xochik
func _elegir_punto_aparicion() -> void:
	var j := get_tree().get_first_node_in_group("jugador") as Node2D
	var x := inicio_x
	for intento in 6:
		x = inicio_x + randf_range(-distancia_patrulla, distancia_patrulla)
		if j == null or absf(x - j.global_position.x) > 160.0:
			break
	global_position.x = x
	dir = 1.0 if randf() < 0.5 else -1.0


# ---------- Utilidades ----------

func _mostrar_icono(txt: String, color: Color) -> void:
	_icono.text = txt
	_icono.modulate = color
	_icono.visible = true


func _play(nombre: String) -> void:
	if anim.sprite_frames and anim.sprite_frames.has_animation(nombre):
		anim.play(nombre)
	elif anim.sprite_frames and anim.sprite_frames.has_animation("idle"):
		anim.play("idle")


func _visible_en_pantalla() -> bool:
	var nivel = get_tree().get_first_node_in_group("nivel")
	return nivel == null or not nivel.has_method("misma_pantalla") or nivel.misma_pantalla(global_position)
