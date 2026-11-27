class_name CastleSwitch
extends Node2D

signal activated(switch_node: Node2D)

var is_activated: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurt_box: HurtBox = $HurtBox


func _ready() -> void:
	add_to_group("castle_switch")
	if hurt_box:
		hurt_box.team = "switch"
	if sprite:
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, 16, 16)


func take_hit(_amount: int = 1, _source_pos: Vector2 = Vector2.ZERO) -> void:
	if is_activated:
		return
	is_activated = true
	if sprite:
		sprite.region_rect = Rect2(16, 0, 16, 16)
	if hurt_box:
		hurt_box.set_deferred("monitoring", false)
		hurt_box.set_deferred("monitorable", false)
	if AudioManager:
		AudioManager.play_switch_sfx()
	_spawn_sparks()
	activated.emit(self)


func hurt() -> void:
	take_hit(1)


func _spawn_sparks() -> void:
	var target_parent := get_tree().get_first_node_in_group("pickups_container")
	if target_parent == null:
		target_parent = get_parent()
	if target_parent == null:
		return
	for i in range(6):
		var sp := ColorRect.new()
		sp.size = Vector2(5, 5)
		sp.color = Color("#38d9a9") if i % 2 == 0 else Color("#ffd166")
		sp.global_position = global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		target_parent.call_deferred("add_child", sp)
		var tw := sp.create_tween()
		tw.set_parallel(true)
		tw.tween_property(sp, "global_position", sp.global_position + Vector2(randf_range(-28, 28), randf_range(-34, -8)), 0.35)
		tw.tween_property(sp, "modulate:a", 0.0, 0.35)
		tw.chain().tween_callback(sp.queue_free)
