extends Ai

enum State {
	PATROL,
	ALERT,
	CHASE,
	STUNNED,
	DEAD
}

const PATROL_SPEED: float = 82.0
const CHASE_SPEED: float = 195.0
const JUMP_VELOCITY: float = -460.0
const GRAVITY: float = 1150.0
const PATROL_RADIUS: float = 125.0

var state: State = State.PATROL
var patrol_dir: float = -1.0
var alert_timer: float = 0.0
var stun_timer: float = 0.0
var jump_cooldown: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_box: HitBox = $HitBox


func _ready() -> void:
	max_hp = 2 if is_boss_minion else 3
	aggro_range = 650.0 if is_boss_minion else 380.0
	coin_drop_min = 1
	coin_drop_max = 1 if is_boss_minion else 2
	super._ready()
	if sprite:
		sprite.modulate = base_modulate
	if hit_box:
		hit_box.team = "enemy"
		hit_box.damage = 1
		hit_box.continuous = true
		hit_box.enable_hitbox()


func set_boss_minion(enabled: bool) -> void:
	super.set_boss_minion(enabled)
	if enabled:
		max_hp = 2
		hp = 2
		aggro_range = 680.0
		coin_drop_min = 1
		coin_drop_max = 1


func take_hit(amount: int = 1, source_pos: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	hp = maxi(0, hp - amount)
	queue_redraw()
	if hp <= 0:
		_die_rat()
		return

	var push_dir := signf(global_position.x - source_pos.x)
	if push_dir == 0.0:
		push_dir = -patrol_dir
	velocity.x = push_dir * 75.0
	if AudioManager:
		AudioManager.play_hit_sfx()
	_flash_tint(Color(1.7, 1.7, 1.7))


func hurt() -> void:
	take_hit(1)


func on_blocked_by_player(shield_pos: Vector2) -> void:
	if is_dead:
		return
	var push_dir := signf(global_position.x - shield_pos.x)
	if push_dir == 0.0:
		push_dir = -patrol_dir
	velocity = Vector2(push_dir * 220.0, -160.0)
	state = State.STUNNED
	stun_timer = 0.45
	_flash_tint(Color(1.5, 1.4, 0.55))


func _flash_tint(col: Color) -> void:
	if not sprite:
		return
	sprite.modulate = col
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", base_modulate, 0.16)


func _die_rat() -> void:
	if is_dead:
		return
	is_dead = true
	state = State.DEAD
	if hit_box:
		hit_box.disable_hitbox()
	if AudioManager:
		AudioManager.play_enemy_die_sfx()
	_drop_coins()
	_spawn_death_burst(Color(0.68, 0.3, 0.95, 1.0) if is_boss_minion else Color(0.55, 0.2, 0.28, 1.0))
	enemy_died.emit(self)
	queue_free()


func _spawn_death_burst(color: Color) -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	for i in range(6):
		var chip := ColorRect.new()
		chip.size = Vector2(6, 6)
		chip.color = color if i % 2 == 0 else Color(0.25, 0.25, 0.3, 1.0)
		chip.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 4))
		parent_node.add_child(chip)
		var tw := chip.create_tween()
		var offset := Vector2(randf_range(-42, 42), randf_range(-46, -12))
		tw.set_parallel(true)
		tw.tween_property(chip, "global_position", chip.global_position + offset, 0.32)
		tw.tween_property(chip, "modulate:a", 0.0, 0.32)
		tw.chain().tween_callback(chip.queue_free)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if jump_cooldown > 0.0:
		jump_cooldown = maxf(0.0, jump_cooldown - delta)

	var can_see_target := false
	var dist_to_target := INF
	var dy := 0.0
	if is_target_alive():
		dist_to_target = global_position.distance_to(target.global_position)
		dy = absf(target.global_position.y - global_position.y)
		can_see_target = dist_to_target <= aggro_range and dy < 190.0

	match state:
		State.PATROL:
			velocity.x = patrol_dir * PATROL_SPEED
			if is_on_wall() or absf(global_position.x - spawn_position.x) > PATROL_RADIUS:
				if (global_position.x - spawn_position.x) * patrol_dir > 0.0 or is_on_wall():
					patrol_dir *= -1.0
			if can_see_target:
				state = State.ALERT
				alert_timer = 0.14
				velocity.x = 0.0
				if sprite:
					sprite.modulate = Color(1.3, 0.75, 0.75)

		State.ALERT:
			velocity.x = 0.0
			alert_timer -= delta
			if is_target_alive() and sprite:
				var face_dir := signf(target.global_position.x - global_position.x)
				if face_dir != 0.0:
					sprite.flip_h = face_dir < 0.0
			if alert_timer <= 0.0:
				if sprite:
					sprite.modulate = base_modulate
				state = State.CHASE if can_see_target else State.PATROL

		State.CHASE:
			if not is_target_alive() or dist_to_target > aggro_range * 1.45:
				state = State.PATROL
				velocity.x = 0.0
			else:
				var dir: float = signf(target.global_position.x - global_position.x)
				if dir == 0.0:
					dir = patrol_dir
				velocity.x = dir * CHASE_SPEED

				var height_diff: float = target.global_position.y - global_position.y
				if height_diff < -36.0 and absf(target.global_position.x - global_position.x) < 180.0 and is_on_floor() and jump_cooldown <= 0.0:
					velocity.y = JUMP_VELOCITY
					jump_cooldown = 0.85

		State.STUNNED:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			stun_timer -= delta
			if stun_timer <= 0.0:
				state = State.CHASE if can_see_target else State.PATROL

	move_and_slide()
