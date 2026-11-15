extends Character


signal facing_left
signal facing_right
signal attack_started
signal attack_finished


enum Direction {
	LEFT = -1,
	RIGHT = 1
}


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
var facing_direction: Direction = Direction.RIGHT
@onready var animator = $AnimatedSprite2D


func attack() -> void:
	attack_started.emit()
	animator.attack()


func has_flipped_direction(direction: Direction) -> bool:
	return direction != facing_direction


func flip_direction_to(direction: Direction) -> void:
	if(direction == Direction.RIGHT):
		facing_right.emit()
		return
	
	if(direction == Direction.LEFT):
		facing_left.emit()
		return


func get_direction(axis: float) -> Direction:
	if axis < 0:
		return Direction.LEFT
		
	if axis > 0:
		return Direction.RIGHT
		
	return facing_direction


func _ready() -> void:
	animator.attack_animation_finished.connect(
		_on_attack_animation_finished
	)


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		attack()
		
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var axis: float = Input.get_axis("left", "right")

	if axis:
		velocity.x = axis * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	var direction: Direction = get_direction(axis)
		
	if(has_flipped_direction(direction)):
		flip_direction_to(direction)
		facing_direction = direction
	
	move_and_slide()


func _on_attack_animation_finished() -> void:
	attack_finished.emit()
