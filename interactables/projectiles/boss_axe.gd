class_name BossAxe
extends CharacterBody2D

enum State {
	FLYING,
	FALLING,
	STUCK
}

const FLY_SPEED: float = 420.0
const MAX_RANGE: float = 440.0
const GRAVITY: float = 980.0

var state: State = State.FLYING
var direction: float = 1.0
var damage: int = 2
var distance_traveled: float = 0.0
var hit_player_once: bool = false
var bob_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_area: Area2D = $HitArea


func launch(dir: float, dmg: int = 2) -> void:
	direction = 1.0 if dir >= 0.0 else -1.0
	damage = maxi(1, dmg)
	state = State.FLYING


func is_stuck() -> bool:
	return state == State.STUCK


func pickup_by_boss() -> void:
	_spawn_sparks()
	queue_free()


func _ready() -> void:
	add_to_group("boss_axe")
	if hit_area:
		hit_area.body_entered.connect(_on_hit_body_entered)


func _physics_process(delta: float) -> void:
	match state:
		State.FLYING:
			velocity = Vector2(direction * FLY_SPEED, 0.0)
			var prev_x := global_position.x
			move_and_slide()
			distance_traveled += absf(global_position.x - prev_x)
			if sprite:
				sprite.rotation += direction * delta * 16.0
			_check_player_overlap()
			if is_on_wall():
				_enter_stuck(false)
			elif distance_traveled >= MAX_RANGE:
				state = State.FALLING

		State.FALLING:
			velocity.x = move_toward(velocity.x, 0.0, 420.0 * delta)
			velocity.y += GRAVITY * delta
			move_and_slide()
			if sprite:
				sprite.rotation += direction * delta * 10.0
			_check_player_overlap()
			if is_on_floor() or is_on_wall():
				_enter_stuck(is_on_floor())

		State.STUCK:
			bob_time += delta
			if sprite:
				var glow := 1.0 + sin(bob_time * 6.0) * 0.25
				sprite.modulate = Color(glow * 0.95, glow * 0.72, glow * 1.25, 1.0)


func _check_player_overlap() -> void:
	if hit_player_once or not hit_area:
		return
	for body in hit_area.get_overlapping_bodies():
		_on_hit_body_entered(body)
		if hit_player_once:
			break


func _on_hit_body_entered(body: Node2D) -> void:
	if state == State.STUCK or hit_player_once or body == null:
		return
	if body.is_in_group("player") and body.has_method("take_hit_from"):
		hit_player_once = true
		body.take_hit_from(damage, global_position, null, 2)


func _enter_stuck(in_floor: bool) -> void:
	if state == State.STUCK:
		return
	state = State.STUCK
	velocity = Vector2.ZERO
	if hit_area:
		hit_area.set_deferred("monitoring", false)
	if sprite:
		sprite.rotation = (PI * 0.85) if in_floor else (PI * 0.5 * direction)
	if AudioManager:
		AudioManager.play_hit_sfx()


func _spawn_sparks() -> void:
	var p_node := get_parent()
	if p_node == null:
		return
	for i in range(5):
		var sp := ColorRect.new()
		sp.size = Vector2(5, 5)
		sp.color = Color("#c084fc") if i % 2 == 0 else Color("#7e22ce")
		sp.global_position = global_position
		p_node.add_child(sp)
		var tw := sp.create_tween()
		tw.set_parallel(true)
		tw.tween_property(sp, "global_position", sp.global_position + Vector2(randf_range(-24, 24), randf_range(-28, 6)), 0.26)
		tw.tween_property(sp, "modulate:a", 0.0, 0.26)
		tw.chain().tween_callback(sp.queue_free)
