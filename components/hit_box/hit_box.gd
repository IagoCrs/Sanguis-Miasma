class_name HitBox
extends Area2D

@export var team: String = "player"
@export var damage: int = 1
@export var shield_cost: int = 1
@export var continuous: bool = false
@export var start_enabled: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _hit_targets: Array[Node] = []


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	if start_enabled:
		enable_hitbox()
	else:
		disable_hitbox()


func enable_hitbox() -> void:
	_hit_targets.clear()
	set_deferred("monitoring", true)
	if collision_shape:
		collision_shape.set_deferred("disabled", false)


func disable_hitbox() -> void:
	_hit_targets.clear()
	set_deferred("monitoring", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)


func _physics_process(_delta: float) -> void:
	if continuous and monitoring:
		for area in get_overlapping_areas():
			_try_hit_area(area)


func _on_area_entered(area: Area2D) -> void:
	_try_hit_area(area)


func _try_hit_area(area: Area2D) -> void:
	if not (area is HurtBox):
		return

	var target: Node = area.get_parent()
	if target == null or target == get_parent():
		return

	var hurt_box := area as HurtBox
	if hurt_box.team == "destructible" or hurt_box.team == "switch":
		if team != "player":
			return
	elif hurt_box.team == team:
		return

	if not continuous:
		if target in _hit_targets:
			return
		_hit_targets.append(target)

	if target.has_method("take_hit_from"):
		target.take_hit_from(damage, global_position, get_parent(), shield_cost)
	elif target.has_method("take_hit"):
		target.take_hit(damage, global_position)
	elif target.has_method("hurt"):
		target.hurt()
