extends Node2D


@onready var hit_box: HitBox = get_parent()
@onready var knight: CharacterBody2D = hit_box.get_parent()


func _on_attack_started() -> void:
	hit_box.enable_hitbox()


func _on_attack_finished() -> void:
	hit_box.disable_hitbox()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	knight.attack_started.connect(_on_attack_started)
	knight.attack_finished.connect(_on_attack_finished)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
