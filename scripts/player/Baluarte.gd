class_name Baluarte
extends PlayerBase

## Baluarte.gd - Player 1 (O Tanque com Escudo de Ossos)
## Sanguis & Miasma: O Preço da Cura (Godot 4.x)
##
## Especialista em defesa com bloqueio pesado e ataques sísmicos.

@export var heavy_attack_damage: float = 35.0
@export var seismic_wave_scene: PackedScene = null

var is_blocking: bool = false
var block_cooldown: float = 0.0

func _init() -> void:
	player_id = 1
	base_speed = 140.0
	jump_velocity = -320.0
	# ==============================================================================
	# AJUSTE AQUI: Dimensões dos frames da spritesheet do Baluarte (128x128 padrão)
	# ==============================================================================
	sprite_frame_width = 128
	sprite_frame_height = 128

func _ready() -> void:
	super._ready()
	# Adiciona animação específica de postura com escudo (Linha 4, 4 quadros de bloqueio)
	if animator:
		animator.add_animation("block", {
			"row": 4,
			"col": 0,
			"frames": 4,
			"fps": 6.0,
			"loop": true,
			"frame_w": sprite_frame_width,
			"frame_h": sprite_frame_height
		})

func _physics_process(delta: float) -> void:
	if block_cooldown > 0.0:
		block_cooldown -= delta

	# Processar Entrada de Escudo / Bloqueio
	if Input.is_action_pressed("p1_shield") and block_cooldown <= 0.0 and is_on_floor():
		if not is_blocking and AudioManager:
			AudioManager.play_shield_block_sfx()
		is_blocking = true
		velocity.x *= 0.2
		if sprite: sprite.modulate = Color(0.7, 0.8, 1.0)
	else:
		if is_blocking:
			is_blocking = false
			if sprite and not invulnerable: sprite.modulate = Color(1.0, 1.0, 1.0)

	# Processar Ataque Pesado
	if Input.is_action_just_pressed("p1_attack") and not is_attacking and not is_blocking:
		_execute_heavy_attack()

	super._physics_process(delta)

func _process_animation(delta: float) -> void:
	# Prioridade máxima para postura de escudo do Baluarte
	if is_blocking and animator:
		animator.play("block")
		return
	super._process_animation(delta)

func _execute_heavy_attack() -> void:
	is_attacking = true
	
	var is_phase1_plus = MiasmaManager.p1_phase >= MiasmaManager.MiasmaPhase.PHASE_1_MUTATION
	perform_attack_deal_damage(heavy_attack_damage, is_phase1_plus)
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.2, 0.85), 0.1)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)
		
	await get_tree().create_timer(0.35).timeout
	is_attacking = false

func is_blocking_active() -> bool:
	return is_blocking
