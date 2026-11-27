class_name DestructibleCrate
extends Node2D

signal crate_broken(crate: Node2D, dropped_heart: bool)

const HEART_PICKUP_SCENE: PackedScene = preload("res://interactables/pickup/heart_pickup.tscn")
const COIN_PICKUP_SCENE: PackedScene = preload("res://interactables/pickup/coin_pickup.tscn")
const SPLINTER_TEXTURE: Texture2D = preload("res://assets/sprites/objects/wood_splinter.png")
const CRATE_GOLD_TEXTURE: Texture2D = preload("res://assets/sprites/objects/crate_gold.png")

@export var hits_to_break: int = 1
@export_range(0.0, 1.0) var base_drop_chance: float = 0.45
@export var guaranteed_heart: bool = false
@export var drop_mode: String = "heart" # "heart", "coins", "both"
@export var coin_min: int = 2
@export var coin_max: int = 4

var hits_remaining: int = 1
var is_broken: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurt_box: HurtBox = $HurtBox
@onready var stand_collision: CollisionShape2D = $StandTop/CollisionShape2D


func _ready() -> void:
	add_to_group("crate")
	hits_remaining = maxi(1, hits_to_break)
	if hurt_box:
		hurt_box.team = "destructible"
	if sprite:
		if drop_mode == "coins":
			sprite.texture = CRATE_GOLD_TEXTURE
			sprite.region_enabled = false
		else:
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 0, 16, 16)


func take_hit(amount: int = 1, _source_pos: Vector2 = Vector2.ZERO) -> void:
	if is_broken:
		return

	hits_remaining -= amount
	if hits_remaining > 0:
		if sprite and drop_mode != "coins":
			sprite.region_rect = Rect2(16, 0, 16, 16)
			sprite.modulate = Color(1.4, 1.4, 1.4)
			var tw := create_tween()
			tw.tween_property(sprite, "modulate", Color.WHITE, 0.14)
		if AudioManager:
			AudioManager.play_hit_sfx()
		return

	_break_crate()


func hurt() -> void:
	take_hit(1)


func _break_crate() -> void:
	is_broken = true
	if hurt_box:
		hurt_box.set_deferred("monitoring", false)
		hurt_box.set_deferred("monitorable", false)
	if stand_collision:
		stand_collision.set_deferred("disabled", true)

	if AudioManager:
		AudioManager.play_crate_break_sfx()

	_spawn_splinters()
	var dropped := false
	if drop_mode == "heart" or drop_mode == "both":
		dropped = _try_spawn_heart()
	if drop_mode == "coins" or drop_mode == "both":
		_spawn_coins()

	crate_broken.emit(self, dropped)
	queue_free()


func _compute_drop_chance() -> float:
	if guaranteed_heart:
		return 1.0
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.get("current_hearts") != null:
		var hearts: int = int(player.get("current_hearts"))
		var max_h: int = int(player.get("max_hearts")) if player.get("max_hearts") != null else 3
		if hearts <= 1:
			return 0.85
		elif hearts < max_h:
			return 0.55
		else:
			return 0.25
	return base_drop_chance


func _get_pickups_parent() -> Node:
	var target_parent := get_tree().get_first_node_in_group("pickups_container")
	if target_parent == null:
		target_parent = get_parent()
	return target_parent


func _try_spawn_heart() -> bool:
	if randf() > _compute_drop_chance():
		return false

	var pickup := HEART_PICKUP_SCENE.instantiate()
	var target_parent := _get_pickups_parent()
	if target_parent == null:
		pickup.queue_free()
		return false

	pickup.global_position = global_position + Vector2(0, -10)
	target_parent.call_deferred("add_child", pickup)
	return true


func _spawn_coins() -> void:
	var target_parent := _get_pickups_parent()
	if target_parent == null:
		return
	var count := randi_range(coin_min, coin_max)
	for _i in range(count):
		var coin := COIN_PICKUP_SCENE.instantiate()
		coin.global_position = global_position + Vector2(randf_range(-8, 8), -10)
		target_parent.call_deferred("add_child", coin)


func _spawn_splinters() -> void:
	var target_parent := _get_pickups_parent()
	if target_parent == null:
		return

	for i in range(7):
		var chip := Sprite2D.new()
		chip.texture = SPLINTER_TEXTURE
		chip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		chip.scale = Vector2(2.5, 2.5)
		chip.global_position = global_position + Vector2(randf_range(-14, 14), randf_range(-14, 10))
		target_parent.add_child(chip)
		var tw := chip.create_tween()
		var dx := randf_range(-58.0, 58.0)
		var peak_y := randf_range(-44.0, -18.0)
		tw.set_parallel(true)
		tw.tween_property(chip, "global_position:x", chip.global_position.x + dx, 0.42)
		tw.tween_property(chip, "rotation", randf_range(-4.5, 4.5), 0.42)
		tw.tween_property(chip, "modulate:a", 0.0, 0.42)
		tw.tween_method(
			func(t: float) -> void:
				if is_instance_valid(chip):
					chip.position.y += (peak_y + 180.0 * t) * 0.016,
			0.0,
			1.0,
			0.42
		)
		tw.chain().tween_callback(chip.queue_free)
