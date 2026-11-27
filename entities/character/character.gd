class_name Character
extends CharacterBody2D


func hurt() -> void:
	pass


func take_hit(_amount: int = 1, _source_pos: Vector2 = Vector2.ZERO) -> void:
	hurt()


func die() -> void:
	queue_free()
