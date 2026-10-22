extends AnimatedSprite2D


signal attack_animation_finished


@onready var knight: CharacterBody2D = get_parent()
var is_attacking: bool = false


func attack() -> void:
	if is_attacking:
		return

	is_attacking = true
	play("attack")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	knight.facing_left.connect(_on_facing_left)
	knight.facing_right.connect(_on_facing_right)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta) -> void:
		
	var is_moving_left: bool = knight.velocity.x > 1
	var is_moving_right: bool = knight.velocity.x < -1
	var is_moving_downwards: bool = knight.velocity.y > 1
	var is_moving_upwards: bool = knight.velocity.y < -1
	
	if is_attacking: 
		return
	
	if is_moving_upwards:
		play("jump")
	
	elif is_moving_downwards:
		play("fall")
	
	elif is_moving_left or is_moving_right:
		play("walk")
	
	else:
		play("idle")


func _on_animation_finished() -> void:
	if animation == "attack":
		is_attacking = false
		attack_animation_finished.emit()


func _on_facing_left() -> void:
	flip_h = true


func _on_facing_right() -> void:
	flip_h = false
