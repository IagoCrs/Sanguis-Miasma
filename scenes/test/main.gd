extends Node2D

@onready var player := $Knight

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for enemy in $Enemies.get_children():
		if enemy is Ai:
			enemy.track(player)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
	
func enemies_alive() -> int:
	return $Enemies.get_child_count()
