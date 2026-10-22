class_name AcidProjectile
extends Area2D

## AcidProjectile.gd - Projétil de Bile Ácida do Cão Pestilento
## Sanguis & Miasma: O Preço da Cura

@export var speed: float = 260.0
@export var damage: float = 14.0
@export var miasma_amount: float = 12.0
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerBase:
		body.apply_hit(damage, miasma_amount)
		queue_free()
	elif body is TileMap or body is StaticBody2D:
		queue_free()
