extends Character

signal facing_left
signal facing_right
signal attack_started
signal attack_finished
signal health_changed(current_hearts: int, max_hearts: int)
signal shield_changed(current_shield: int, max_shield: int)
signal sword_state_changed(has_sword: bool)
signal player_damaged(current_hearts: int)
signal player_blocked
signal player_healed(current_hearts: int)
signal player_died
signal coin_collected(amount: int)

enum Direction {
	LEFT = -1,
	RIGHT = 1
}

const SPEED: float = 305.0
const GUARD_SPEED: float = 130.0
const JUMP_VELOCITY: float = -720.0
const GRAVITY: float = 1280.0
const COYOTE_TIME_MAX: float = 0.12
const JUMP_BUFFER_MAX: float = 0.12
const CASTLE_FONT: Font = preload("res://assets/fonts/castle_pixel.fnt")

@export var max_hearts: int = 3
@export var invulnerable_duration: float = 1.25
@export var sword_damage: int = 1
@export var max_shield: int = 2
@export var shield_recharge_time: float = 3.0

var current_hearts: int = 3
var current_shield: int = 2
var has_sword: bool = true
var is_defending: bool = false
var invulnerable_timer: float = 0.0
var block_grace_timer: float = 0.0
var shield_recharge_timer: float = 0.0
var knockback_timer: float = 0.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var notice_timer: float = 0.0
var is_dead: bool = false
var can_control: bool = true
var facing_direction: Direction = Direction.RIGHT

@onready var animator: AnimatedSprite2D = $AnimatedSprite2D
@onready var shield_sprite: Sprite2D = $ShieldSprite
@onready var hit_box: HitBox = $HitBox

var notice_label: Label = null


func _ready() -> void:
	current_hearts = clampi(current_hearts, 0, max_hearts)
	current_shield = clampi(current_shield, 0, max_shield)
	if hit_box:
		hit_box.damage = sword_damage
	animator.attack_animation_finished.connect(_on_attack_animation_finished)
	_create_notice_label()
	_update_shield_visual()
	health_changed.emit(current_hearts, max_hearts)
	shield_changed.emit(current_shield, max_shield)
	sword_state_changed.emit(has_sword)


func _create_notice_label() -> void:
	notice_label = Label.new()
	notice_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.position = Vector2(-75, -70)
	notice_label.size = Vector2(150, 22)
	notice_label.add_theme_font_override("font", CASTLE_FONT)
	notice_label.add_theme_font_size_override("font_size", 16)
	notice_label.add_theme_color_override("font_color", Color("#ffd166"))
	notice_label.add_theme_color_override("font_outline_color", Color("#120e17"))
	notice_label.add_theme_constant_override("outline_size", 4)
	notice_label.visible = false
	add_child(notice_label)


func show_notice(text_val: String, color: Color = Color("#ffd166")) -> void:
	if notice_label:
		notice_label.text = text_val
		notice_label.modulate = color
		notice_label.visible = true
		notice_timer = 1.1


func apply_stats(hearts: int, max_h: int, dmg: int, max_sh: int, recharge_t: float) -> void:
	max_hearts = maxi(1, max_h)
	current_hearts = clampi(hearts, 0, max_hearts)
	sword_damage = maxi(1, dmg)
	max_shield = maxi(1, max_sh)
	current_shield = clampi(current_shield, 0, max_shield)
	if current_shield == 0:
		current_shield = max_shield
	shield_recharge_time = maxf(0.8, recharge_t)
	if hit_box:
		hit_box.damage = sword_damage
	health_changed.emit(current_hearts, max_hearts)
	shield_changed.emit(current_shield, max_shield)


func set_hearts(value: int) -> void:
	current_hearts = clampi(value, 0, max_hearts)
	is_dead = current_hearts <= 0
	health_changed.emit(current_hearts, max_hearts)


func collect_coin(amount: int = 1) -> void:
	coin_collected.emit(amount)


func retrieve_sword() -> void:
	if has_sword:
		return
	has_sword = true
	sword_state_changed.emit(true)
	show_notice("Espada recuperada!", Color("#b8ffe5"))
	if AudioManager:
		AudioManager.play_sword_pickup_sfx()


func attack() -> void:
	if is_dead or not can_control or is_defending or animator.is_attacking or animator.is_throwing:
		return
	if not has_sword:
		show_notice("Sem espada!", Color("#ff8a8a"))
		if AudioManager:
			AudioManager.play_shop_deny_sfx()
		return
	if hit_box:
		hit_box.damage = sword_damage
	attack_started.emit()
	animator.attack()
	if AudioManager:
		AudioManager.play_attack_sfx()


func throw_sword() -> bool:
	if is_dead or not can_control or is_defending or animator.is_attacking or animator.is_throwing:
		return false
	if not has_sword:
		show_notice("Espada já lançada!", Color("#ff8a8a"))
		if AudioManager:
			AudioManager.play_shop_deny_sfx()
		return false

	has_sword = false
	sword_state_changed.emit(false)
	animator.throw_sword()
	if AudioManager:
		AudioManager.play_sword_throw_sfx()
	_spawn_thrown_sword()
	return true


func _spawn_thrown_sword() -> void:
	var sword_scene: PackedScene = load("res://interactables/sword/thrown_sword.tscn")
	if sword_scene == null:
		return
	var sword := sword_scene.instantiate()
	var target_parent := get_tree().get_first_node_in_group("pickups_container")
	if target_parent == null:
		target_parent = get_parent()
	if target_parent == null:
		sword.queue_free()
		return

	sword.global_position = global_position + Vector2(float(facing_direction) * 26.0, -6.0)
	if sword.has_method("launch"):
		sword.launch(float(facing_direction), sword_damage + 1)
	target_parent.call_deferred("add_child", sword)


func take_hit(amount: int = 1, source_pos: Vector2 = Vector2.ZERO) -> void:
	take_hit_from(amount, source_pos, null)


func take_hit_from(amount: int = 1, source_pos: Vector2 = Vector2.ZERO, attacker: Node = null, shield_cost: int = 1) -> void:
	if is_dead or not can_control:
		return

	# Active Shield Defense blocks the attack!
	if is_defending and current_shield > 0:
		if block_grace_timer > 0.0:
			return
		var drain := mini(current_shield, maxi(1, shield_cost))
		current_shield = maxi(0, current_shield - drain)
		block_grace_timer = 0.55
		shield_recharge_timer = shield_recharge_time
		shield_changed.emit(current_shield, max_shield)
		player_blocked.emit()

		var push_dir: float = signf(global_position.x - source_pos.x)
		if push_dir == 0.0:
			push_dir = -float(facing_direction)
		velocity = Vector2(push_dir * 105.0, velocity.y)
		knockback_timer = 0.12

		if AudioManager:
			AudioManager.play_shield_block_sfx()
		_spawn_block_sparks()
		_flash_shield()
		if attacker != null and attacker.has_method("on_blocked_by_player"):
			attacker.on_blocked_by_player(global_position)
		if current_shield <= 0:
			is_defending = false
			_update_shield_visual()
			show_notice("Escudo esgotado!", Color("#ffd166"))
		return

	if invulnerable_timer > 0.0:
		return

	current_hearts = maxi(0, current_hearts - amount)
	health_changed.emit(current_hearts, max_hearts)
	player_damaged.emit(current_hearts)

	var dir: float = signf(global_position.x - source_pos.x)
	if dir == 0.0:
		dir = -float(facing_direction)
	velocity = Vector2(dir * 230.0, -210.0)
	knockback_timer = 0.22
	invulnerable_timer = invulnerable_duration

	if AudioManager:
		AudioManager.play_player_hurt_sfx()

	if current_hearts <= 0:
		is_dead = true
		can_control = false
		is_defending = false
		_update_shield_visual()
		if hit_box:
			hit_box.disable_hitbox()
		animator.play_death()
		player_died.emit()
	else:
		animator.play_hurt()


func heal(amount: int = 1) -> bool:
	if is_dead or current_hearts >= max_hearts:
		return false

	current_hearts = mini(max_hearts, current_hearts + amount)
	health_changed.emit(current_hearts, max_hearts)
	player_healed.emit(current_hearts)
	_flash_heal()
	return true


func _flash_heal() -> void:
	if not is_instance_valid(animator):
		return
	var tween := create_tween()
	animator.modulate = Color(1.4, 0.75, 0.85, 1.0)
	tween.tween_property(animator, "modulate", Color.WHITE, 0.28)


func _flash_shield() -> void:
	if not is_instance_valid(shield_sprite):
		return
	shield_sprite.modulate = Color(1.7, 1.7, 1.7)
	var tw := create_tween()
	tw.tween_property(shield_sprite, "modulate", Color.WHITE, 0.16)


func _spawn_block_sparks() -> void:
	var target_parent := get_tree().get_first_node_in_group("pickups_container")
	if target_parent == null:
		target_parent = get_parent()
	if target_parent == null:
		return
	for i in range(6):
		var sp := ColorRect.new()
		sp.size = Vector2(5, 5)
		sp.color = Color("#a8c2e0") if i % 2 == 0 else Color("#ffd166")
		sp.global_position = global_position + Vector2(float(facing_direction) * 26.0, -8.0)
		target_parent.add_child(sp)
		var tw := sp.create_tween()
		tw.set_parallel(true)
		tw.tween_property(sp, "global_position", sp.global_position + Vector2(randf_range(-34, 34), randf_range(-36, 10)), 0.28)
		tw.tween_property(sp, "modulate:a", 0.0, 0.28)
		tw.chain().tween_callback(sp.queue_free)


func _update_shield_visual() -> void:
	if shield_sprite:
		shield_sprite.visible = is_defending and not is_dead
		shield_sprite.position = Vector2(float(facing_direction) * 26.0, -4.0)
		shield_sprite.flip_h = facing_direction == Direction.LEFT


func has_flipped_direction(direction: Direction) -> bool:
	return direction != facing_direction


func flip_direction_to(direction: Direction) -> void:
	if direction == Direction.RIGHT:
		facing_right.emit()
	elif direction == Direction.LEFT:
		facing_left.emit()


func get_direction(axis: float) -> Direction:
	if axis < 0.0:
		return Direction.LEFT
	if axis > 0.0:
		return Direction.RIGHT
	return facing_direction


func _process(delta: float) -> void:
	if invulnerable_timer > 0.0:
		invulnerable_timer = maxf(0.0, invulnerable_timer - delta)
		if not is_dead:
			var blink_on := fmod(invulnerable_timer, 0.14) < 0.07
			animator.modulate = Color(1.0, 0.55, 0.55, 0.45) if blink_on else Color(1.0, 0.85, 0.85, 1.0)
			if invulnerable_timer <= 0.0:
				animator.modulate = Color.WHITE

	if block_grace_timer > 0.0:
		block_grace_timer = maxf(0.0, block_grace_timer - delta)

	if notice_timer > 0.0:
		notice_timer -= delta
		if notice_timer <= 0.0 and notice_label:
			notice_label.visible = false

	# Shield passive recharge when not holding guard
	if not is_dead and not is_defending and current_shield < max_shield:
		shield_recharge_timer -= delta
		if shield_recharge_timer <= 0.0:
			current_shield = mini(max_shield, current_shield + 1)
			shield_changed.emit(current_shield, max_shield)
			if current_shield < max_shield:
				shield_recharge_timer = shield_recharge_time


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		coyote_timer = maxf(0.0, coyote_timer - delta)
	else:
		coyote_timer = COYOTE_TIME_MAX

	if is_dead:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * delta * 3.0)
		move_and_slide()
		return

	if not can_control:
		is_defending = false
		_update_shield_visual()
		velocity.x = move_toward(velocity.x, 0.0, SPEED * delta * 4.0)
		move_and_slide()
		return

	if knockback_timer > 0.0:
		knockback_timer = maxf(0.0, knockback_timer - delta)

	var wants_defend := Input.is_action_pressed("defend")
	if wants_defend and current_shield > 0 and not animator.is_attacking and not animator.is_throwing:
		is_defending = true
	else:
		is_defending = false
	_update_shield_visual()

	if Input.is_action_just_pressed("attack"):
		attack()
	elif Input.is_action_just_pressed("throw_sword"):
		throw_sword()

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_MAX
	else:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0
		jump_buffer_timer = 0.0
		if AudioManager:
			AudioManager.play_jump_sfx()

	if Input.is_action_just_released("jump") and velocity.y < -220.0:
		velocity.y *= 0.55

	var axis: float = Input.get_axis("left", "right")
	var move_spd := GUARD_SPEED if is_defending else SPEED
	if knockback_timer <= 0.0:
		if axis != 0.0:
			velocity.x = axis * move_spd
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_spd)

		var direction: Direction = get_direction(axis)
		if has_flipped_direction(direction):
			flip_direction_to(direction)
			facing_direction = direction
			_update_shield_visual()

	move_and_slide()


func _on_attack_animation_finished() -> void:
	attack_finished.emit()
