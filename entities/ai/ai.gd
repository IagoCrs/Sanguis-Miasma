class_name Ai
extends Character

signal enemy_died(enemy: Node)

const COIN_PICKUP_SCENE: PackedScene = preload("res://interactables/pickup/coin_pickup.tscn")
const CORRUPTED_SHADER: Shader = preload("res://shaders/corrupted_tint.gdshader")

@export var max_hp: int = 1
@export var aggro_range: float = 340.0
@export var coin_drop_min: int = 1
@export var coin_drop_max: int = 2

var hp: int = 1
var is_dead: bool = false
var is_boss_minion: bool = false
var spawn_position: Vector2 = Vector2.ZERO
var target: Character
var base_modulate: Color = Color.WHITE


func _ready() -> void:
	hp = max_hp
	spawn_position = global_position
	if is_boss_minion:
		apply_corrupted_visual(Color(0.76, 0.22, 0.98, 1.0), 0.85)


func apply_corrupted_visual(tint: Color = Color(0.76, 0.22, 0.98, 1.0), strength: float = 0.85) -> void:
	var anim := get_node_or_null("AnimatedSprite2D") as CanvasItem
	if not anim:
		return
	var mat := ShaderMaterial.new()
	mat.shader = CORRUPTED_SHADER
	mat.set_shader_parameter("tint_color", tint)
	mat.set_shader_parameter("strength", strength)
	anim.material = mat
	anim.modulate = Color.WHITE


func set_boss_minion(enabled: bool) -> void:
	is_boss_minion = enabled
	base_modulate = Color.WHITE
	var anim := get_node_or_null("AnimatedSprite2D") as CanvasItem
	if enabled:
		apply_corrupted_visual(Color(0.76, 0.22, 0.98, 1.0), 0.85)
	elif anim:
		anim.material = null
		anim.modulate = Color.WHITE


func track(value: Character) -> void:
	self.target = value


func has_target() -> bool:
	return self.target != null


func is_target_alive() -> bool:
	return has_target() and is_instance_valid(target) and not bool(target.get("is_dead"))


func untrack() -> void:
	self.target = null


func on_blocked_by_player(_shield_pos: Vector2) -> void:
	pass


func _drop_coins() -> void:
	if coin_drop_max <= 0:
		return
	var target_parent := get_tree().get_first_node_in_group("pickups_container")
	if target_parent == null:
		target_parent = get_parent()
	if target_parent == null:
		return
	var count := randi_range(coin_drop_min, coin_drop_max)
	for _i in range(count):
		var coin := COIN_PICKUP_SCENE.instantiate()
		coin.global_position = global_position + Vector2(randf_range(-8, 8), -8)
		target_parent.call_deferred("add_child", coin)


func _draw() -> void:
	if max_hp <= 1 or max_hp > 8 or hp <= 0 or hp >= max_hp:
		return
	var pip_w := 10.0
	var pip_h := 4.0
	var gap := 3.0
	var total_w := max_hp * pip_w + (max_hp - 1) * gap
	var start_x := -total_w * 0.5
	var y := -48.0
	for i in range(max_hp):
		var rect := Rect2(start_x + i * (pip_w + gap), y, pip_w, pip_h)
		draw_rect(rect.grow(1.0), Color("#140c1c"))
		var col := Color("#d62848") if i < hp else Color("#2b2d3e")
		draw_rect(rect, col)
