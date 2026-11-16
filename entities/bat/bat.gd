extends Ai

const SPEED = 200.0
const JUMP_VELOCITY = -400.0

func hurt()->void :
	self.die()

func _physics_process(_delta: float) -> void:
	if has_target():
		var direction := (target.global_position - global_position).normalized()
		velocity = direction * SPEED
		move_and_slide()
