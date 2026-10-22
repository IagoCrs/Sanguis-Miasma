extends Node2D


@onready var hit_box: HitBox = get_parent()
@onready var knight: CharacterBody2D = hit_box.get_parent()


var default_x: float


func _on_facing_left() -> void:
	hit_box.position.x = -default_x


func _on_facing_right() -> void:
	hit_box.position.x = default_x


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	default_x = abs(hit_box.position.x)
	knight.facing_left.connect(_on_facing_left)
	knight.facing_right.connect(_on_facing_right)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
