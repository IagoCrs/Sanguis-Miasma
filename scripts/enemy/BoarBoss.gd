class_name BoarBoss
extends EnemyBase

## BoarBoss.gd - Javali com Carapaça Óssea (Mini-Boss do Alfa)
## Sanguis & Miasma: O Preço da Cura (Godot 4.x)
##
## Mini-chefe blindado na dianteira com ataque de investida destrutiva e mecânica de atordoamento.

@export var charge_speed: float = 320.0
@export var stagger_duration: float = 3.0

var facing_direction: float = 1.0
var is_charging: bool = false
var charge_cooldown: float = 0.0
var stagger_timer: float = 0.0

func _init() -> void:
	max_health = 160.0
	move_speed = 60.0
	attack_damage = 25.0
	miasma_on_hit = 20.0
	detection_radius = 350.0
	attack_radius = 50.0
	
	# ==============================================================================
	# AJUSTE AQUI: Dimensões dos frames da spritesheet do Chefe Javali (em pixels)
	# ==============================================================================
	enemy_frame_width = 80
	enemy_frame_height = 64

func _setup_animator() -> void:
	super._setup_animator()
	if animator:
		# boar_boss_sheet.png (4 colunas x 2 linhas)
		var boss_anims: Dictionary = {
			"idle": {
				"row": 0,
				"col": 0,
				"frames": 2,
				"fps": 4.0,
				"loop": true,
				"frame_w": enemy_frame_width,
				"frame_h": enemy_frame_height
			},
			"run": {
				"row": 0,
				"col": 0,
				"frames": 4,
				"fps": 8.0,
				"loop": true,
				"frame_w": enemy_frame_width,
				"frame_h": enemy_frame_height
			},
			"charge": {
				"row": 0,
				"col": 0,
				"frames": 4,
				"fps": 14.0,
				"loop": true,
				"frame_w": enemy_frame_width,
				"frame_h": enemy_frame_height
			},
			"attack": {
				"row": 1,
				"col": 0,
				"frames": 2,
				"fps": 10.0,
				"loop": false,
				"frame_w": enemy_frame_width,
				"frame_h": enemy_frame_height
			},
			"hurt": {
				"row": 1,
				"col": 2,
				"frames": 1,
				"fps": 1.0,
				"loop": false,
				"frame_w": enemy_frame_width,
				"frame_h": enemy_frame_height
			},
			"stagger": {
				"row": 1,
				"col": 1,
				"frames": 2,
				"fps": 4.0,
				"loop": true,
				"frame_w": enemy_frame_width,
				"frame_h": enemy_frame_height
			},
			"dead": {
				"row": 1,
				"col": 3,
				"frames": 1,
				"fps": 1.0,
				"loop": false,
				"frame_w": enemy_frame_width,
				"frame_h": enemy_frame_height
			}
		}
		animator.setup(sprite, boss_anims, enemy_frame_width, enemy_frame_height)

func _update_animation() -> void:
	if animator == null: return
	
	if is_charging:
		animator.play("charge")
		return
		
	match current_state:
		State.IDLE:
			animator.play("idle")
		State.CHASE, State.PATROL:
			animator.play("run")
		State.ATTACK:
			animator.play("attack")
		State.STAGGER:
			animator.play("stagger")
		State.DEAD:
			animator.play("dead")

func _state_logic(delta: float) -> void:
	if charge_cooldown > 0.0:
		charge_cooldown -= delta

	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, move_speed * delta * 2)
			if target_player:
				current_state = State.CHASE

		State.CHASE:
			if target_player == null:
				current_state = State.IDLE
				return
				
			facing_direction = sign(target_player.global_position.x - global_position.x)
			if facing_direction == 0: facing_direction = 1.0
			if sprite: sprite.flip_h = (facing_direction < 0)
			
			var dist = global_position.distance_to(target_player.global_position)
			
			if dist >= 90.0 and charge_cooldown <= 0.0:
				_start_charge()
			else:
				velocity.x = facing_direction * move_speed

		State.ATTACK:
			if is_charging:
				velocity.x = facing_direction * charge_speed
				
				if attack_area and attack_area.has_overlapping_bodies():
					for body in attack_area.get_overlapping_bodies():
						if body is PlayerBase:
							if body.has_method("is_blocking_active") and body.is_blocking_active():
								_trigger_stagger()
								return
							else:
								deal_damage_to_player(body)
								
				if is_on_wall():
					_trigger_stagger()

		State.STAGGER:
			stagger_timer -= delta
			velocity.x = move_toward(velocity.x, 0, move_speed * delta * 4)
			
			if sprite:
				sprite.modulate = Color(1.0, 0.9, 0.3) if fmod(stagger_timer, 0.2) > 0.1 else Color(0.8, 0.6, 0.1)
				
			if stagger_timer <= 0.0:
				current_state = State.CHASE
				if sprite: sprite.modulate = Color(1.0, 1.0, 1.0)
				charge_cooldown = 2.5

func _start_charge() -> void:
	current_state = State.ATTACK
	is_charging = true
	if sprite: sprite.modulate = Color(1.0, 0.5, 0.5)

func _trigger_stagger() -> void:
	is_charging = false
	current_state = State.STAGGER
	stagger_timer = stagger_duration
	charge_cooldown = 3.5
	velocity.x = -facing_direction * 120.0
	if AudioManager: AudioManager.play_boss_stagger_sfx()

func _die() -> void:
	super._die()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud == null:
		hud = get_node_or_null("../HUD")
	if hud and hud.has_method("trigger_victory"):
		hud.trigger_victory()

func take_enemy_damage(amount: float, attacker_id: int, hit_dir: float, is_aoe: bool = false) -> void:
	if current_state == State.DEAD: return
	
	if current_state == State.STAGGER:
		super.take_enemy_damage(amount * 2.0, attacker_id, hit_dir, is_aoe)
		return
		
	var is_hit_from_front = (facing_direction * hit_dir < 0)
	
	if is_hit_from_front and not is_aoe:
		_play_carapace_block_effect()
		return
	else:
		var critical_amount = amount * 3.0
		super.take_enemy_damage(critical_amount, attacker_id, hit_dir, is_aoe)

func _play_carapace_block_effect() -> void:
	hit_flash_timer = 0.1
	if sprite: sprite.modulate = Color(0.9, 0.9, 1.0)
