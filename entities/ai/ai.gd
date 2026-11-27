class_name Ai
extends Character

signal enemy_died(enemy: Node)

const COIN_PICKUP_SCENE: PackedScene = preload("res://interactables/pickup/coin_pickup.tscn")

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
var minion_aura: Polygon2D = null
var aura_time: float = 0.0


func _ready() -> void:
	hp = max_hp
	spawn_position = global_position


func _process(delta: float) -> void:
	if is_instance_valid(minion_aura) and not is_dead:
		aura_time += delta
		var pulse := 1.0 + sin(aura_time * 5.2) * 0.14
		minion_aura.scale = Vector2(pulse, pulse)
		minion_aura.color.a = 0.28 + sin(aura_time * 5.2) * 0.10


func set_boss_minion(enabled: bool) -> void:
	is_boss_minion = enabled
	if enabled:
		base_modulate = Color(0.84, 0.58, 1.0)
		var anim := get_node_or_null("AnimatedSprite2D")
		if anim:
			anim.modulate = base_modulate
		if minion_aura == null:
			minion_aura = Polygon2D.new()
			minion_aura.z_index = -1
			minion_aura.color = Color(0.65, 0.25, 0.96, 0.34)
			var pts: PackedVector2Array = []
			for i in range(10):
				var ang := float(i) * TAU / 10.0
				pts.append(Vector2(cos(ang) * 34.0, sin(ang) * 28.0))
			minion_aura.polygon = pts
			add_child(minion_aura)
			move_child(minion_aura, 0)
	else:
		base_modulate = Color.WHITE
		if is_instance_valid(minion_aura):
			minion_aura.queue_free()
			minion_aura = null


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
