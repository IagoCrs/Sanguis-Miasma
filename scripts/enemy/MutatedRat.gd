class_name MutatedRat
extends EnemyBase

## MutatedRat.gd - Rato de Esgoto Mutado
## Sanguis & Miasma: O Preço da Cura (Godot 4.x)
##
## Inimigo rápido e errático que salta sobre as pernas dos jogadores.

var leap_timer: float = 0.0
var is_leaping: bool = false

func _init() -> void:
	max_health = 25.0
	move_speed = 150.0
	attack_damage = 8.0
	miasma_on_hit = 5.0
	detection_radius = 220.0
	attack_radius = 24.0
	
	# ==============================================================================
	# AJUSTE AQUI: Dimensões dos frames da spritesheet do Rato Mutado (em pixels)
	# ==============================================================================
	enemy_frame_width = 32
	enemy_frame_height = 24

func _setup_animator() -> void:
	super._setup_animator()
	if animator:
		# Configurações específicas para mutated_rat_sheet.png (4 frames na horizontal)
		var rat_anims: Dictionary = {
			"idle": {
				"row": 0,
				"col": 0,
				"frames": 2,
				"fps": 6.0,
				"loop": true,
				"frame_w": enemy_frame_width,
				"frame_h": enemy_frame_height
			},
			"run": {
				"row": 0,
				"col": 0,
				"frames": 4,
				"fps": 12.0,
				"loop": true,
				"frame_w": enemy_frame_width,
				"frame_h": enemy_frame_height
			},
			"attack": {
				"row": 0,
				"col": 2,
				"frames": 2,
				"fps": 12.0,
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
		animator.setup(sprite, rat_anims, enemy_frame_width, enemy_frame_height)

func _state_logic(delta: float) -> void:
	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, move_speed * delta * 2)
			if target_player:
				current_state = State.CHASE
				
		State.CHASE:
			if target_player == null:
				current_state = State.IDLE
				return
				
			var dist = global_position.distance_to(target_player.global_position)
			var dir = sign(target_player.global_position.x - global_position.x)
			
			if sprite: sprite.flip_h = (dir < 0)
			
			if dist <= attack_radius and is_on_floor():
				current_state = State.ATTACK
				_perform_leap_attack(dir)
			else:
				velocity.x = dir * move_speed
				
		State.ATTACK:
			if is_leaping:
				if attack_area and attack_area.has_overlapping_bodies():
					for body in attack_area.get_overlapping_bodies():
						if body is PlayerBase:
							deal_damage_to_player(body)
							break
							
				if is_on_floor() and velocity.y >= 0:
					is_leaping = false
					current_state = State.CHASE

func _perform_leap_attack(dir: float) -> void:
	is_leaping = true
	velocity.x = dir * (move_speed * 1.6)
	velocity.y = -220.0
