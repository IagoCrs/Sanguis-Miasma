class_name HeartPickup
extends CharacterBody2D

const GRAVITY: float = 980.0

var bob_time: float = 0.0
var pickup_delay: float = 0.18
var consumed: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_area: Area2D = $PickupArea


func _ready() -> void:
	add_to_group("heart_pickup")
	velocity = Vector2(randf_range(-45.0, 45.0), -220.0)
	if pickup_area:
		pickup_area.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if consumed:
		return

	if pickup_delay > 0.0:
		pickup_delay = maxf(0.0, pickup_delay - delta)

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, 320.0 * delta)

	move_and_slide()

	bob_time += delta
	if sprite:
		sprite.position.y = sin(bob_time * 4.5) * 4.0
		var pulse := 2.5 + sin(bob_time * 5.0) * 0.12
		sprite.scale = Vector2(pulse, pulse)

	if pickup_delay <= 0.0 and pickup_area:
		for body in pickup_area.get_overlapping_bodies():
			_try_collect(body)
			if consumed:
				break


func _on_body_entered(body: Node2D) -> void:
	if pickup_delay <= 0.0:
		_try_collect(body)


func _try_collect(body: Node2D) -> void:
	if consumed or body == null:
		return
	if body.has_method("heal"):
		if body.heal(1):
			consumed = true
			if AudioManager:
				AudioManager.play_heart_pickup_sfx()
			_spawn_heal_sparkles()
			queue_free()


func _spawn_heal_sparkles() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	for i in range(6):
		var p := ColorRect.new()
		p.size = Vector2(5, 5)
		p.color = Color("#ff4d6d") if i % 2 == 0 else Color("#ffd1da")
		p.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		parent_node.add_child(p)
		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "global_position", p.global_position + Vector2(randf_range(-24, 24), randf_range(-38, -14)), 0.35)
		tw.tween_property(p, "modulate:a", 0.0, 0.35)
		tw.chain().tween_callback(p.queue_free)
