class_name Ceifador
extends PlayerBase

## Ceifador.gd - Player 2 (O Ceifador Ágil)
## Sanguis & Miasma: O Preço da Cura (Godot 4.x)
##
## Especialista em alta mobilidade, Shadow Dash, salto duplo e ataques rápidos.

@export var light_attack_damage: float = 20.0
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.25

var can_double_jump: bool = false
var has_double_jumped: bool = false
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown: float = 0.0

func _init() -> void:
	player_id = 2
	base_speed = 180.0
	jump_velocity = -360.0
	# ==============================================================================
	# AJUSTE AQUI: Dimensões dos frames da spritesheet do Ceifador (128x128 padrão)
	# ==============================================================================
	sprite_frame_width = 128
	sprite_frame_height = 128

func _ready() -> void:
	super._ready()
	# Adiciona animação específica de Shadow Dash / Investida sombria
	if animator:
		animator.add_animation("dash", {
			"row": 3,
			"col": 0,
			"frames": 4,
			"fps": 16.0,
			"loop": true,
			"frame_w": sprite_frame_width,
			"frame_h": sprite_frame_height
		})

func _physics_process(delta: float) -> void:
	if dash_cooldown > 0.0:
		dash_cooldown -= delta
		
	# Reset do pulo duplo ao tocar o chão
	if is_on_floor():
		has_double_jumped = false
		can_double_jump = true
		
	# Lógica do Shadow Dash
	if is_dashing:
		dash_timer -= delta
		var dash_dir = -1.0 if sprite and sprite.flip_h else 1.0
		velocity.x = dash_dir * dash_speed
		velocity.y = 0.0
		
		# Efeito visual de Rastro Sombrio (Fase 1+ Miasma)
		if MiasmaManager.p2_phase >= MiasmaManager.MiasmaPhase.PHASE_1_MUTATION:
			_create_shadow_ghost()
			
		if dash_timer <= 0.0:
			is_dashing = false
			collision_layer = 1
			collision_mask = 1
			if sprite and not invulnerable: sprite.modulate = Color(1.0, 1.0, 1.0)
			
		move_and_slide()
		_process_animation(delta)
		return
		
	# Ativação do Shadow Dash
	if Input.is_action_just_pressed("p2_dash") and dash_cooldown <= 0.0 and not is_dashing:
		_start_shadow_dash()
		
	# Pulo Duplo no ar
	if Input.is_action_just_pressed("p2_jump") and not is_on_floor() and can_double_jump and not has_double_jumped:
		velocity.y = jump_velocity * 0.9
		has_double_jumped = true
		can_double_jump = false
		
		if sprite:
			var tween = create_tween()
			tween.tween_property(sprite, "rotation", TAU, 0.25)
			tween.tween_property(sprite, "rotation", 0.0, 0.0)
			
	# Ataque Rápido
	if Input.is_action_just_pressed("p2_attack") and not is_attacking and not is_dashing:
		_execute_light_attack()
		
	super._physics_process(delta)

func _process_animation(delta: float) -> void:
	if is_dashing and animator:
		animator.play("dash")
		return
	super._process_animation(delta)

func _start_shadow_dash() -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown = 0.6
	if AudioManager: AudioManager.play_dash_sfx()
	collision_layer = 2
	
	if sprite:
		sprite.modulate = Color(0.3, 0.1, 0.4, 0.7)

func _execute_light_attack() -> void:
	is_attacking = true
	
	var is_aoe = MiasmaManager.p2_phase >= MiasmaManager.MiasmaPhase.PHASE_2_MAX_POWER
	perform_attack_deal_damage(light_attack_damage, is_aoe)
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "position:x", sprite.position.x + (10.0 if not sprite.flip_h else -10.0), 0.05)
		tween.tween_property(sprite, "position:x", 0.0, 0.08)
		
	await get_tree().create_timer(0.2).timeout
	is_attacking = false

func _create_shadow_ghost() -> void:
	if sprite == null or get_parent() == null: return
	var ghost = Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.region_enabled = sprite.region_enabled
	ghost.region_rect = sprite.region_rect
	ghost.global_position = global_position
	ghost.flip_h = sprite.flip_h
	ghost.modulate = Color(0.5, 0.1, 0.6, 0.4)
	get_parent().add_child(ghost)
	
	var tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tween.tween_callback(ghost.queue_free)

func is_dashing_active() -> bool:
	return is_dashing
