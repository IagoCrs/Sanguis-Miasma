extends AnimatedSprite2D


@onready var rat: CharacterBody2D = get_parent()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var is_moving_left: bool = rat.velocity.x > 1
	var is_moving_right: bool = rat.velocity.x < -1
	var is_moving_downwards: bool = rat.velocity.y > 1
	var is_moving_upwards: bool = rat.velocity.y < -1
	
	if is_moving_upwards:
		play("jump")
	elif is_moving_downwards:
		play("fall")
	elif is_moving_left or is_moving_right:
		play("walk")
	else:
		play("idle")
	
	if is_moving_left:
		flip_h = false
	
	if is_moving_right:
		flip_h = true
	
	pass
