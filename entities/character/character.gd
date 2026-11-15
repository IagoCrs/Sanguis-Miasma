class_name Character
extends CharacterBody2D

func attack(target: Character)-> void:
	target.hurt()

func hurt()-> void:
	pass

func die():
	queue_free()
