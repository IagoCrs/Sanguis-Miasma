class_name Character
extends CharacterBody2D

func hurt()-> void:
	pass

func die():
	queue_free()
