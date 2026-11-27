class_name HurtBox
extends Area2D

@export var team: String = "player"


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(_area: Area2D) -> void:
	pass
