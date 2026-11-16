extends Ai


const SPEED = 250.0
const JUMP_VELOCITY = -400.0


func hurt()->void:
	self.die();


func _physics_process(delta: float) -> void:
	if not has_target():
		pass
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	var direction: float = sign(
		target.global_position.x - global_position.x
	)
	
	velocity.x = direction * SPEED
	
	var height_difference: float = target.global_position.y - global_position.y

	if height_difference < -32 and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()
