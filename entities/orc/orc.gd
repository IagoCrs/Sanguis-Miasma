extends Ai

signal boss_hp_changed(hp: int, max_hp: int)
signal boss_horde_requested(wave: int)
signal boss_defeated_signal

const BOSS_AXE_SCENE: PackedScene = preload("res://interactables/projectiles/boss_axe.tscn")
const CASTLE_FONT: Font = preload("res://assets/fonts/castle_pixel.fnt")

enum State {
	PATROL,
	CHASE,
	TELEGRAPH,
	ATTACK,
	DASH_TELEGRAPH,
	DASH_ATTACK,
	AXE_THROW_TELEGRAPH,
	RETRIEVE_AXE,
	RECOVER,
	RETREATED,
	DEAD
}

const GRAVITY: float = 1150.0
const PATROL_SPEED: float = 78.0
const PATROL_RADIUS: float = 120.0

@export var is_boss: bool = false

var state: State = State.PATROL
var facing_dir: float = -1.0
var patrol_dir: float = -1.0
var state_timer: float = 0.0
var dash_cooldown: float = 1.5
var dash_dir: float = -1.0
var axe_throw_cooldown: float = 4.0
var has_axe: bool = true
var active_axe: BossAxe = null
var combat_active: bool = true
var current_wave_triggered: int = 0
var chase_speed: float = 132.0
var attack_range: float = 104.0
var base_tint: Color = Color.WHITE
var arena_home_position: Vector2 = Vector2.ZERO
var retreat_position: Vector2 = Vector2(720.0, 210.0)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hurt_box: HurtBox = $HurtBox
@onready var hit_box: HitBox = $HitBox

var warn_label: Label = null


func _ready() -> void:
	if is_boss:
		max_hp = 32
		aggro_range = 1300.0
		chase_speed = 148.0
		attack_range = 114.0
		coin_drop_min = 12
		coin_drop_max = 15
		base_tint = Color.WHITE
		combat_active = false
		if sprite:
			sprite.scale = Vector2(5.8, 5.8)
			sprite.modulate = base_tint
		apply_corrupted_visual(Color(0.84, 0.16, 0.94, 1.0), 0.88)
		if collision_shape:
			var rect := collision_shape.shape as RectangleShape2D
			if rect:
				var boss_rect := rect.duplicate()
				boss_rect.size = Vector2(68, 86)
				collision_shape.shape = boss_rect
			collision_shape.position = Vector2(0, -4)
		if hurt_box:
			hurt_box.scale = Vector2(3.4, 4.2)
			hurt_box.position = Vector2(0, -4)
		if hit_box:
			hit_box.scale = Vector2(3.7, 3.7)
	else:
		max_hp = 5 if is_boss_minion else 7
		aggro_range = 850.0 if is_boss_minion else 400.0
		chase_speed = 132.0
		attack_range = 104.0
		coin_drop_min = 2 if is_boss_minion else 3
		coin_drop_max = 3 if is_boss_minion else 5
		base_tint = base_modulate

	super._ready()
	arena_home_position = global_position
	retreat_position = Vector2(arena_home_position.x, 195.0)
	_create_warn_label()
	if hurt_box:
		hurt_box.team = "enemy"
	if hit_box:
		hit_box.team = "enemy"
		hit_box.damage = 2 if is_boss else 1
		hit_box.shield_cost = 1
		hit_box.continuous = false
		hit_box.disable_hitbox()
	if sprite:
		sprite.animation_finished.connect(_on_animation_finished)
		sprite.frame_changed.connect(_on_frame_changed)
		sprite.play("idle")
	_apply_facing(facing_dir)
	if is_boss:
		boss_hp_changed.emit(hp, max_hp)


func set_boss_minion(enabled: bool) -> void:
	super.set_boss_minion(enabled)
	if enabled and not is_boss:
		max_hp = 5
		hp = 5
		aggro_range = 900.0
		coin_drop_min = 2
		coin_drop_max = 3
		base_tint = base_modulate
		if sprite:
			sprite.modulate = base_tint


func _create_warn_label() -> void:
	warn_label = Label.new()
	warn_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	warn_label.text = "!"
	warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_label.position = Vector2(-60, -88 if is_boss else -68)
	warn_label.size = Vector2(120, 28)
	warn_label.add_theme_font_override("font", CASTLE_FONT)
	warn_label.add_theme_font_size_override("font_size", 26)
	warn_label.add_theme_color_override("font_color", Color("#ff5a1f"))
	warn_label.add_theme_color_override("font_outline_color", Color("#0d0c14"))
	warn_label.add_theme_constant_override("outline_size", 5)
	warn_label.visible = false
	add_child(warn_label)


func _set_warn_visible(show_it: bool, text_val: String = "!", col: Color = Color("#ff5a1f")) -> void:
	if warn_label:
		warn_label.text = text_val
		warn_label.modulate = col
		warn_label.visible = show_it


func start_boss_combat() -> void:
	combat_active = true
	state = State.CHASE


func _apply_facing(dir: float) -> void:
	if dir == 0.0:
		return
	facing_dir = signf(dir)
	if sprite:
		sprite.flip_h = facing_dir < 0.0
	if hit_box:
		var offset_x := 62.0 if is_boss else 44.0
		hit_box.position = Vector2(facing_dir * offset_x, -2.0)


func take_hit(amount: int = 1, source_pos: Vector2 = Vector2.ZERO) -> void:
	if is_dead or state == State.RETREATED or (is_boss and not combat_active):
		return

	var next_hp := maxi(0, hp - amount)
	if is_boss:
		if current_wave_triggered == 0 and next_hp <= 24:
			next_hp = 24
		elif current_wave_triggered == 1 and next_hp <= 16:
			next_hp = 16
		elif current_wave_triggered == 2 and next_hp <= 8:
			next_hp = 8

	hp = next_hp
	queue_redraw()
	if is_boss:
		boss_hp_changed.emit(hp, max_hp)

	if state != State.ATTACK and state != State.TELEGRAPH and state != State.DASH_ATTACK and state != State.DASH_TELEGRAPH:
		var push_dir := signf(global_position.x - source_pos.x)
		if push_dir == 0.0:
			push_dir = -facing_dir
		velocity.x = push_dir * (45.0 if is_boss else 85.0)

	if hp <= 0:
		_enter_death()
		return

	if is_boss:
		if current_wave_triggered == 0 and hp <= 24:
			current_wave_triggered = 1
			_enter_retreat(1)
			return
		elif current_wave_triggered == 1 and hp <= 16:
			current_wave_triggered = 2
			_enter_retreat(2)
			return
		elif current_wave_triggered == 2 and hp <= 8:
			current_wave_triggered = 3
			_enter_retreat(3)
			return

	if AudioManager:
		AudioManager.play_hit_sfx()
	_flash_tint(Color(1.7, 1.7, 1.7))


func hurt() -> void:
	take_hit(1)


func on_blocked_by_player(shield_pos: Vector2) -> void:
	if is_dead or state == State.RETREATED:
		return
	if hit_box:
		hit_box.disable_hitbox()
	_set_warn_visible(false)
	var push_dir := signf(global_position.x - shield_pos.x)
	if push_dir == 0.0:
		push_dir = -facing_dir
	velocity.x = push_dir * (165.0 if is_boss else 210.0)
	state = State.RECOVER
	state_timer = 0.65
	if sprite:
		sprite.play("idle")
	_flash_tint(Color(1.5, 1.4, 0.55))


func _flash_tint(col: Color) -> void:
	if not sprite:
		return
	sprite.modulate = col
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", base_tint, 0.16)


func _enter_retreat(wave: int) -> void:
	state = State.RETREATED
	_set_warn_visible(false)
	if hit_box:
		hit_box.disable_hitbox()
	if hurt_box:
		hurt_box.set_deferred("monitoring", false)
		hurt_box.set_deferred("monitorable", false)
	if is_instance_valid(active_axe):
		active_axe.pickup_by_boss()
		active_axe = null
	has_axe = true
	velocity = Vector2.ZERO
	if sprite:
		sprite.play("idle")
	if AudioManager:
		AudioManager.play_boss_roar_sfx()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", retreat_position, 0.45)
	tw.tween_property(self, "scale", Vector2(0.75, 0.75), 0.45)
	tw.tween_property(self, "modulate", Color(0.7, 0.6, 0.9, 0.62), 0.45)
	boss_horde_requested.emit(wave)


func return_from_retreat(wave_cleared: int) -> void:
	if is_dead:
		return
	chase_speed = 148.0 + float(wave_cleared) * 14.0
	if wave_cleared >= 3:
		apply_corrupted_visual(Color(0.96, 0.16, 0.42, 1.0), 0.90)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "global_position", arena_home_position, 0.42)
	tw.tween_property(self, "scale", Vector2.ONE, 0.42)
	tw.tween_property(self, "modulate", Color.WHITE, 0.42)
	await tw.finished
	if not is_instance_valid(self) or is_dead:
		return
	if sprite:
		sprite.modulate = base_tint
	if hurt_box:
		hurt_box.set_deferred("monitoring", true)
		hurt_box.set_deferred("monitorable", true)
	if AudioManager:
		AudioManager.play_boss_roar_sfx()
	state = State.CHASE


func _spawn_boss_axe() -> void:
	var target_parent := get_tree().get_first_node_in_group("pickups_container")
	if target_parent == null:
		target_parent = get_parent()
	if target_parent == null:
		return
	var axe := BOSS_AXE_SCENE.instantiate() as BossAxe
	axe.global_position = global_position + Vector2(facing_dir * 42.0, -14.0)
	axe.launch(facing_dir, 2)
	target_parent.add_child(axe)
	active_axe = axe
	has_axe = false
	axe_throw_cooldown = 6.2
	if AudioManager:
		AudioManager.play_axe_throw_sfx()


func _enter_death() -> void:
	is_dead = true
	state = State.DEAD
	_set_warn_visible(false)
	if hit_box:
		hit_box.disable_hitbox()
	if hurt_box:
		hurt_box.set_deferred("monitoring", false)
		hurt_box.set_deferred("monitorable", false)
	if is_instance_valid(active_axe):
		active_axe.pickup_by_boss()
		active_axe = null
	if AudioManager:
		AudioManager.play_enemy_die_sfx()
	_drop_coins()
	if sprite:
		sprite.modulate = base_tint
		sprite.play("death")
	queue_redraw()
	enemy_died.emit(self)
	if is_boss:
		boss_defeated_signal.emit()
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if state == State.RETREATED:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if is_dead:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		return

	if is_boss and not combat_active:
		velocity.x = 0.0
		if sprite and sprite.animation != "idle":
			sprite.play("idle")
		move_and_slide()
		return

	if dash_cooldown > 0.0:
		dash_cooldown = maxf(0.0, dash_cooldown - delta)
	if axe_throw_cooldown > 0.0:
		axe_throw_cooldown = maxf(0.0, axe_throw_cooldown - delta)

	var dist_to_target := INF
	var can_aggro := false
	if is_target_alive():
		dist_to_target = global_position.distance_to(target.global_position)
		can_aggro = dist_to_target <= aggro_range

	match state:
		State.PATROL:
			velocity.x = patrol_dir * PATROL_SPEED
			_apply_facing(patrol_dir)
			if is_on_wall() or absf(global_position.x - spawn_position.x) > PATROL_RADIUS:
				if (global_position.x - spawn_position.x) * patrol_dir > 0.0 or is_on_wall():
					patrol_dir *= -1.0
			if sprite:
				sprite.play("walk")
			if can_aggro:
				state = State.CHASE

		State.CHASE:
			if is_boss and not has_axe:
				state = State.RETRIEVE_AXE
				return
			if not is_target_alive() or (not is_boss and dist_to_target > aggro_range * 1.45):
				state = State.PATROL
				return
			var dir := signf(target.global_position.x - global_position.x)
			if dir != 0.0:
				_apply_facing(dir)

			var same_height := absf(target.global_position.y - global_position.y) < 120.0
			if is_boss and has_axe and dist_to_target >= 190.0 and dist_to_target <= 480.0 and axe_throw_cooldown <= 0.0 and same_height:
				state = State.AXE_THROW_TELEGRAPH
				state_timer = 0.55
				velocity.x = 0.0
				_set_warn_visible(true, "MACHADO!", Color("#c084fc"))
				if sprite:
					sprite.play("idle")
					sprite.modulate = Color(1.15, 0.55, 1.55)
			elif dist_to_target >= 105.0 and dist_to_target <= 265.0 and dash_cooldown <= 0.0 and same_height:
				state = State.DASH_TELEGRAPH
				dash_dir = facing_dir
				state_timer = 0.68 if is_boss else 0.62
				velocity.x = 0.0
				_set_warn_visible(true, "!", Color("#ff5a1f"))
				if sprite:
					sprite.play("idle")
					sprite.modulate = Color(1.6, 0.7, 0.35)
			elif dist_to_target <= attack_range and same_height:
				state = State.TELEGRAPH
				if hit_box:
					hit_box.damage = 2 if is_boss else 1
					hit_box.shield_cost = 1
				state_timer = 0.42 if is_boss else 0.30
				velocity.x = 0.0
				if sprite:
					sprite.play("idle")
					sprite.modulate = Color(1.5, 0.55, 0.45)
			else:
				velocity.x = facing_dir * chase_speed
				if sprite:
					sprite.play("walk")

		State.TELEGRAPH:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			state_timer -= delta
			if state_timer <= 0.0:
				state = State.ATTACK
				if sprite:
					sprite.modulate = base_tint
					sprite.play("heavy_attack" if is_boss else "attack")

		State.ATTACK:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)

		State.DASH_TELEGRAPH:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			state_timer -= delta
			if state_timer <= 0.0:
				_set_warn_visible(false)
				state = State.DASH_ATTACK
				state_timer = 0.38 if is_boss else 0.34
				dash_cooldown = 3.2
				if hit_box:
					hit_box.damage = 2 if is_boss else 1
					hit_box.shield_cost = 2 if is_boss else 1
					hit_box.enable_hitbox()
				if sprite:
					sprite.modulate = base_tint
					sprite.play("heavy_attack")
				if AudioManager:
					AudioManager.play_dash_sfx()

		State.DASH_ATTACK:
			var dash_spd := 360.0 if is_boss else 340.0
			velocity.x = dash_dir * dash_spd
			state_timer -= delta
			if state_timer <= 0.0 or is_on_wall():
				if hit_box:
					hit_box.disable_hitbox()
				state = State.RECOVER
				state_timer = 0.72 if is_boss else 0.65
				if sprite:
					sprite.play("idle")

		State.AXE_THROW_TELEGRAPH:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			state_timer -= delta
			if state_timer <= 0.0:
				_set_warn_visible(false)
				if sprite:
					sprite.modulate = base_tint
					sprite.play("attack")
				_spawn_boss_axe()
				state = State.RETRIEVE_AXE

		State.RETRIEVE_AXE:
			if not is_instance_valid(active_axe):
				has_axe = true
				state = State.CHASE
				return
			var dir_x := signf(active_axe.global_position.x - global_position.x)
			if dir_x != 0.0:
				_apply_facing(dir_x)
			velocity.x = dir_x * 175.0
			if sprite and sprite.animation != "walk":
				sprite.play("walk")
			if active_axe.is_stuck() and absf(global_position.x - active_axe.global_position.x) <= 56.0:
				active_axe.pickup_by_boss()
				active_axe = null
				has_axe = true
				velocity.x = 0.0
				state = State.RECOVER
				state_timer = 0.45
				if sprite:
					sprite.play("idle")

		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			state_timer -= delta
			if sprite and sprite.animation != "idle":
				sprite.play("idle")
			if state_timer <= 0.0:
				state = State.CHASE if is_target_alive() else State.PATROL

	move_and_slide()


func _on_frame_changed() -> void:
	if state != State.ATTACK or not sprite or not hit_box:
		return
	if sprite.animation == "attack" or sprite.animation == "heavy_attack":
		if sprite.frame == 3 or sprite.frame == 4:
			hit_box.enable_hitbox()
		else:
			hit_box.disable_hitbox()


func _on_animation_finished() -> void:
	if is_dead or not sprite or state == State.RETREATED:
		return
	if state == State.ATTACK and (sprite.animation == "attack" or sprite.animation == "heavy_attack"):
		if hit_box:
			hit_box.disable_hitbox()
		state = State.RECOVER
		state_timer = 0.55 if is_boss else 0.48
		sprite.play("idle")
