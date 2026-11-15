class_name HitBox
extends Area2D	


@onready var collision_shape: CollisionShape2D = $CollisionShape2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	monitoring = false
	collision_shape.disabled = true
	area_entered.connect(_on_area_entered)


func enable_hitbox() -> void:
	monitoring = true
	collision_shape.disabled = false


func disable_hitbox() -> void:
	monitoring = false
	collision_shape.disabled = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_area_entered(area: Area2D) -> void:
	var source: CharacterBody2D = get_parent()
	var target: CharacterBody2D = area.get_parent()
	
	if area is HurtBox && target is Character:
		print("[HIT] %s [%s] hit %s [%s]" % [
			source.name,
			source.get_instance_id(),
			target.name,
			target.get_instance_id()
		])
		target.hurt()
		return
	
	# TODO: find a way to trigger it once instead of twice for each character
	#if area is HitBox:
		#print("[CLASH] %s [%s] clashed %s [%s]" % [
			#source.name,
			#source.get_instance_id(),
			#target.name,
			#target.get_instance_id()
		#])
		#return
