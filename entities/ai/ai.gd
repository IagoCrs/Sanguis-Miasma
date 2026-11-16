class_name Ai 
extends Character


var target : Character


func track(value: Character) -> void:
	self.target = value


func has_target() -> bool:
	return self.target != null


func untrack()-> void:
	self.target = null
