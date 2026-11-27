class_name CoinPickup
extends CharacterBody2D

signal collected(amount: int)

const GRAVITY: float = 980.0

@export var value: int = 1

var bob_time: float = 0.0
var pickup_delay: float = 0.16
var consumed: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var pickup_area: Area2D = $PickupArea


func _ready() -> void:
	add_to_group("coin_pickup")
	velocity = Vector2(randf_range(-75.0, 75.0), randf_range(-260.0, -190.0))
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
		velocity.x = move_toward(velocity.x, 0.0, 340.0 * delta)

	move_and_slide()

	bob_time += delta
	if sprite:
		sprite.position.y = sin(bob_time * 5.0) * 3.0

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
	if body.has_method("collect_coin"):
		consumed = true
		body.collect_coin(value)
		collected.emit(value)
		if AudioManager:
			AudioManager.play_coin_sfx()
		_spawn_sparkles()
		queue_free()


func _spawn_sparkles() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	for i in range(4):
		var p := ColorRect.new()
		p.size = Vector2(4, 4)
		p.color = Color("#ffd166") if i % 2 == 0 else Color("#fff0a8")
		p.global_position = global_position + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		parent_node.add_child(p)
		var tw := p.create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "global_position", p.global_position + Vector2(randf_range(-20, 20), randf_range(-30, -10)), 0.28)
		tw.tween_property(p, "modulate:a", 0.0, 0.28)
		tw.chain().tween_callback(p.queue_free)
