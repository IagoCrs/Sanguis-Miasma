extends AnimatedSprite2D

signal attack_animation_finished
signal throw_animation_finished

@onready var knight: CharacterBody2D = get_parent()
var is_attacking: bool = false
var is_throwing: bool = false
var is_hurt: bool = false
var is_dead: bool = false


func attack() -> void:
	if is_attacking or is_throwing or is_dead:
		return
	is_attacking = true
	is_hurt = false
	play("attack")


func throw_sword() -> void:
	if is_attacking or is_throwing or is_dead:
		return
	is_throwing = true
	is_hurt = false
	play("throw")


func play_hurt() -> void:
	if is_dead or is_attacking or is_throwing:
		return
	is_hurt = true
	play("hurt")


func play_death() -> void:
	if is_dead:
		return
	is_dead = true
	is_attacking = false
	is_throwing = false
	is_hurt = false
	play("death")


func reset_state() -> void:
	is_dead = false
	is_attacking = false
	is_throwing = false
	is_hurt = false
	modulate = Color.WHITE
	play("idle")


func _ready() -> void:
	knight.facing_left.connect(_on_facing_left)
	knight.facing_right.connect(_on_facing_right)


func _process(_delta: float) -> void:
	if is_dead or is_attacking or is_throwing or is_hurt:
		return

	if knight.get("is_defending"):
		play("defend")
		return

	var is_moving_horizontally: bool = absf(knight.velocity.x) > 1.0
	var is_moving_downwards: bool = knight.velocity.y > 1.0
	var is_moving_upwards: bool = knight.velocity.y < -1.0

	if is_moving_upwards:
		play("jump")
	elif is_moving_downwards:
		play("fall")
	elif is_moving_horizontally:
		play("walk")
	else:
		play("idle")


func _on_animation_finished() -> void:
	if animation == "attack":
		is_attacking = false
		attack_animation_finished.emit()
	elif animation == "throw":
		is_throwing = false
		throw_animation_finished.emit()
	elif animation == "hurt":
		is_hurt = false


func _on_facing_left() -> void:
	flip_h = true


func _on_facing_right() -> void:
	flip_h = false
