class_name PestilenceHound
extends EnemyBase

## PestilenceHound.gd - Cão Pestilento (Lobo Quimérico)
## Sanguis & Miasma: O Preço da Cura (Godot 4.x)
##
## Predador de média distância capaz de cuspir bile ácida e avançar ferozmente.

@export var acid_projectile_scene: PackedScene = null

var spit_cooldown: float = 0.0

func _init() -> void:
	max_health = 45.0
	move_speed = 110.0
	attack_damage = 14.0
	miasma_on_hit = 10.0
	detection_radius = 280.0
	attack_radius = 40.0
	
	# ==============================================================================
	# AJUSTE AQUI: Dimensões dos frames da spritesheet do Cão Pestilento (em pixels)
	# ==============================================================================
	enemy_frame_width = 48
	enemy_frame_height = 32

func _setup_animator() -> void:
	super._setup_animator()
	if animator:
		var hound_anims: Dictionary = {
			"idle": {
				"row": 0,
				"col": 0,
				"frames": 2,
				"fps": 5.0,
				"loop": true,
				"frame_w": enemy_frame_width,
				"frame_h": enemy_frame_height
			},
			"run": {
				"row": 0,
				"col": 0,
				"frames": 4,
				"fps": 10.0,
				"loop": true,
				"frame_w": enemy_frame_width,
				"frame_h": enemy_frame_height
			},
			"attack": {
				"row": 0,
				"col": 2,
				"frames": 2,
				"fps": 8.0,
				"loop": false,
				"frame_w": enemy_frame_width,
				"frame_h": enemy_frame_height
			},
			"hurt": {
				"row": 0,
				"col": 1,
				"frames": 1,
				"fps": 1.0,
				"loop": false,
				"frame_w": enemy_frame_width,
				"frame_h": enemy_frame_height
			},
			"dead": {
				"row": 0,
				"col": 3,
				"frames": 1,
				"fps": 1.0,
				"loop": false,
				"frame_w": enemy_frame_width,
				"frame_h": enemy_frame_height
			}
		}
		animator.setup(sprite, hound_anims, enemy_frame_width, enemy_frame_height)

func _state_logic(delta: float) -> void:
	if spit_cooldown > 0.0:
		spit_cooldown -= delta
		
	match current_state:
		State.IDLE:
			if target_player:
				current_state = State.CHASE
				
		State.CHASE:
			if target_player == null:
				current_state = State.IDLE
				return
				
			var dist = global_position.distance_to(target_player.global_position)
			var dir = sign(target_player.global_position.x - global_position.x)
			if sprite: sprite.flip_h = (dir < 0)
			
			# Média distância: cospe bile ácida
			if dist >= 80.0 and dist <= 220.0 and spit_cooldown <= 0.0:
				_spit_acid(target_player.global_position)
			elif dist <= attack_radius:
				current_state = State.ATTACK
				velocity.x = dir * (move_speed * 1.5)
			else:
				velocity.x = dir * move_speed
				
		State.ATTACK:
			if attack_area and attack_area.has_overlapping_bodies():
				for body in attack_area.get_overlapping_bodies():
					if body is PlayerBase:
						deal_damage_to_player(body)
			
			await get_tree().create_timer(0.4).timeout
			if current_state != State.DEAD:
				current_state = State.CHASE

func _spit_acid(target_pos: Vector2) -> void:
	spit_cooldown = 2.5
	
	var proj_script = load("res://scripts/objects/AcidProjectile.gd")
	var proj = Area2D.new()
	proj.set_script(proj_script)
	
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	proj.add_child(shape)
	
	var proj_sprite = Sprite2D.new()
	proj_sprite.modulate = Color(0.2, 0.9, 0.2)
	proj.add_child(proj_sprite)
	
	proj.global_position = global_position + Vector2(0, -10)
	var dir = (target_pos - proj.global_position).normalized()
	proj.call("set_direction", dir)
	
	get_parent().add_child(proj)
