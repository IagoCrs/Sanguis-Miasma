class_name BatSpit
extends Area2D

var direction: Vector2 = Vector2.LEFT
var speed: float = 290.0
var lifetime: float = 3.5
var trail_timer: float = 0.0
var consumed: bool = false


func launch(dir: Vector2, spd: float = 290.0) -> void:
	direction = dir.normalized() if dir != Vector2.ZERO else Vector2.LEFT
	speed = spd


func _ready() -> void:
	add_to_group("bat_spit")
	collision_layer = 0
	collision_mask = 3
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if consumed:
		return
	global_position += direction * speed * delta
	lifetime -= delta
	trail_timer -= delta
	if trail_timer <= 0.0:
		trail_timer = 0.06
		_spawn_trail_dot()
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if consumed or body == null:
		return
	consumed = true
	if body.is_in_group("player") and body.has_method("take_hit_from"):
		body.take_hit_from(1, global_position, null, 1)
	_spawn_splash()
	queue_free()


func _spawn_trail_dot() -> void:
	var p_node := get_parent()
	if p_node == null:
		return
	var dot := ColorRect.new()
	dot.size = Vector2(5, 5)
	dot.color = Color(0.68, 0.32, 0.95, 0.75)
	dot.global_position = global_position - Vector2(2, 2)
	p_node.add_child(dot)
	var tw := dot.create_tween()
	tw.tween_property(dot, "modulate:a", 0.0, 0.18)
	tw.tween_callback(dot.queue_free)


func _spawn_splash() -> void:
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
		tw.tween_property(sp, "global_position", sp.global_position + Vector2(randf_range(-24, 24), randf_range(-24, 16)), 0.24)
		tw.tween_property(sp, "modulate:a", 0.0, 0.24)
		tw.chain().tween_callback(sp.queue_free)
