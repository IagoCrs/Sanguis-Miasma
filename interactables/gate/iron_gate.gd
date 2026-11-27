class_name IronGate
extends StaticBody2D

var is_open: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("iron_gate")
	collision_layer = 4
	collision_mask = 0


func open_gate() -> void:
	if is_open:
		return
	is_open = true
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if AudioManager:
		AudioManager.play_gate_open_sfx()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 136.0, 0.45)
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(queue_free)
