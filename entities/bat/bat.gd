extends Ai

const BAT_SPIT_SCENE: PackedScene = preload("res://interactables/projectiles/bat_spit.tscn")

enum State {
	HOVER,
	WINDUP,
	SWOOP,
	SPIT_WINDUP,
	RECOVER,
	DEAD
}

const SWOOP_SPEED: float = 235.0
const RECOVER_SPEED: float = 155.0

var state: State = State.HOVER
var hover_time: float = 0.0
var state_timer: float = 0.0
var spit_cooldown: float = 1.4
var attack_toggle: int = 0
var swoop_dir: Vector2 = Vector2.ZERO
var swoop_target_pos: Vector2 = Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_box: HitBox = $HitBox


func _ready() -> void:
	max_hp = 2 if is_boss_minion else 3
	aggro_range = 700.0 if is_boss_minion else 440.0
	coin_drop_min = 1 if is_boss_minion else 2
	coin_drop_max = 2
	super._ready()
	if sprite:
		sprite.modulate = base_modulate
		sprite.play("default")
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
		aggro_range = 750.0
		coin_drop_min = 1
		coin_drop_max = 2


func take_hit(amount: int = 1, _source_pos: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	hp = maxi(0, hp - amount)
	queue_redraw()
	if hp <= 0:
		_die_bat()
		return

	if AudioManager:
		AudioManager.play_hit_sfx()
	_flash_tint(Color(1.7, 1.7, 1.7))


func hurt() -> void:
	take_hit(1)


func on_blocked_by_player(shield_pos: Vector2) -> void:
	if is_dead:
		return
	var push := (global_position - shield_pos).normalized()
	if push == Vector2.ZERO:
		push = Vector2.UP
	velocity = push * 220.0 + Vector2(0, -110.0)
	state = State.RECOVER
	state_timer = 0.75
	_flash_tint(Color(1.5, 1.4, 0.55))


func _flash_tint(col: Color) -> void:
	if not sprite:
		return
	sprite.modulate = col
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", base_modulate, 0.16)


func _fire_purple_spit() -> void:
	if not is_target_alive():
		return
	var target_parent := get_tree().get_first_node_in_group("pickups_container")
	if target_parent == null:
		target_parent = get_parent()
	if target_parent == null:
		return
	var spit := BAT_SPIT_SCENE.instantiate() as BatSpit
	spit.global_position = global_position + Vector2(0, 8)
	var dir := ((target.global_position + Vector2(0, -8)) - spit.global_position).normalized()
	spit.launch(dir, 290.0)
	target_parent.call_deferred("add_child", spit)
	if AudioManager:
		AudioManager.play_spit_sfx()


func _die_bat() -> void:
	if is_dead:
		return
	is_dead = true
	state = State.DEAD
	if hit_box:
		hit_box.disable_hitbox()
	if AudioManager:
		AudioManager.play_enemy_die_sfx()
	_drop_coins()
	_spawn_death_burst()
	enemy_died.emit(self)
	queue_free()


func _spawn_death_burst() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	for i in range(6):
		var chip := ColorRect.new()
		chip.size = Vector2(6, 6)
		chip.color = Color(0.68, 0.3, 0.95, 1.0) if i % 2 == 0 else Color(0.85, 0.2, 0.3, 1.0)
		chip.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-10, 10))
		parent_node.add_child(chip)
		var tw := chip.create_tween()
		var offset := Vector2(randf_range(-44, 44), randf_range(-44, 24))
		tw.set_parallel(true)
		tw.tween_property(chip, "global_position", chip.global_position + offset, 0.32)
		tw.tween_property(chip, "modulate:a", 0.0, 0.32)
		tw.chain().tween_callback(chip.queue_free)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	hover_time += delta
	if spit_cooldown > 0.0:
		spit_cooldown = maxf(0.0, spit_cooldown - delta)

	match state:
		State.HOVER:
			var hover_anchor := spawn_position + Vector2(sin(hover_time * 1.8) * 38.0, sin(hover_time * 3.3) * 14.0)
			velocity = (hover_anchor - global_position) * 4.5
			if sprite and absf(velocity.x) > 4.0:
				sprite.flip_h = velocity.x < 0.0
			if is_target_alive() and global_position.distance_to(target.global_position) <= aggro_range:
				attack_toggle += 1
				var dist := global_position.distance_to(target.global_position)
				if spit_cooldown <= 0.0 and (attack_toggle % 2 == 1 or dist > 150.0):
					state = State.SPIT_WINDUP
					state_timer = 0.42
					velocity = Vector2.ZERO
					if sprite:
						sprite.modulate = Color(1.25, 0.55, 1.75)
				else:
					state = State.WINDUP
					state_timer = 0.24
					velocity = Vector2.ZERO
					if sprite:
						sprite.modulate = Color(1.4, 0.6, 0.6)

		State.SPIT_WINDUP:
			state_timer -= delta
			velocity = Vector2(0.0, sin(hover_time * 14.0) * 14.0)
			if is_target_alive() and sprite:
				sprite.flip_h = target.global_position.x < global_position.x
			if state_timer <= 0.0:
				if sprite:
					sprite.modulate = base_modulate
				_fire_purple_spit()
				spit_cooldown = 2.4
				state = State.RECOVER
				state_timer = 0.50

		State.WINDUP:
			state_timer -= delta
			velocity = Vector2(0.0, sin(hover_time * 18.0) * 18.0)
			if is_target_alive() and sprite:
				sprite.flip_h = target.global_position.x < global_position.x
			if state_timer <= 0.0:
				if sprite:
					sprite.modulate = base_modulate
				if is_target_alive():
					swoop_target_pos = target.global_position + Vector2(0, -14)
					swoop_dir = (swoop_target_pos - global_position).normalized()
					if swoop_dir == Vector2.ZERO:
						swoop_dir = Vector2.DOWN
					state = State.SWOOP
					state_timer = 1.0
				else:
					state = State.RECOVER
					state_timer = 0.55

		State.SWOOP:
			state_timer -= delta
			velocity = swoop_dir * SWOOP_SPEED
			if sprite and absf(velocity.x) > 4.0:
				sprite.flip_h = velocity.x < 0.0
			if state_timer <= 0.0 or global_position.distance_to(swoop_target_pos) < 18.0 or is_on_floor() or is_on_wall():
				state = State.RECOVER
				state_timer = 0.55

		State.RECOVER:
			state_timer -= delta
			var recover_target := Vector2(global_position.x, spawn_position.y)
			if is_target_alive():
				recover_target.x = clampf(target.global_position.x, spawn_position.x - 160.0, spawn_position.x + 160.0)
			var dir := (recover_target - global_position)
			if dir.length() > 10.0:
				velocity = dir.normalized() * RECOVER_SPEED
			else:
				velocity = Vector2.ZERO
			if sprite and absf(velocity.x) > 4.0:
				sprite.flip_h = velocity.x < 0.0
			if state_timer <= 0.0 or global_position.distance_to(recover_target) < 18.0:
				state = State.HOVER

	move_and_slide()
