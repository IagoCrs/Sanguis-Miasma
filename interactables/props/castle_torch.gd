extends Node2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	if sprite and sprite.sprite_frames:
		var count := sprite.sprite_frames.get_frame_count("default")
		if count > 0:
			sprite.frame = randi() % count
			sprite.frame_progress = randf()
