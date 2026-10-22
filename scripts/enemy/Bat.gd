class_name Bat
extends CharacterBody2D

## Bat.gd - Morcego Corrompido por Miasma
## Sanguis & Miasma: O Preço da Cura (Godot 4.x)
##
## Inimigo voador com padrão de deslocamento senoidal e fatiamento UV de asas batendo.

@export var max_hp: float = 30.0
@export var damage: float = 10.0
@export var speed: float = 80.0
@export var detection_range: float = 400.0
@export var miasma_value: float = 5.0

# ==============================================================================
# AJUSTE AQUI: Dimensões dos frames da spritesheet do Morcego (em pixels)
# ==============================================================================
@export var enemy_frame_width: int = 32
@export var enemy_frame_height: int = 32

var current_hp: float
var target: Node2D = null
@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox

var animator: SpriteAnimator = null
var base_y: float = 0.0
var time_alive: float = 0.0

func _ready() -> void:
	current_hp = max_hp
	base_y = position.y
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	_setup_animator()

func _setup_animator() -> void:
	if has_node("SpriteAnimator"):
		animator = $SpriteAnimator as SpriteAnimator
	else:
		animator = SpriteAnimator.new()
		animator.name = "SpriteAnimator"
		add_child(animator)
		
	# miasma_bat_sheet.png (4 frames de bater asas)
	var bat_anims: Dictionary = {
		"fly": {
			"row": 0,
			"col": 0,
			"frames": 4,
			"fps": 10.0,
			"loop": true,
			"frame_w": enemy_frame_width,
			"frame_h": enemy_frame_height
		},
		"idle": {
			"row": 0,
			"col": 0,
			"frames": 4,
			"fps": 8.0,
			"loop": true,
			"frame_w": enemy_frame_width,
			"frame_h": enemy_frame_height
		},
		"hurt": {
			"row": 0,
			"col": 1,
			"frames": 1,
			"fps": 1.0,
			"loop": false,
			"frame_w": enemy_frame_width,
			"frame_h": enemy_frame_height
		}
	}
	animator.setup(sprite, bat_anims, enemy_frame_width, enemy_frame_height)
	animator.play("fly")

func _physics_process(delta: float) -> void:
	time_alive += delta
	_find_target()
	
	if target:
		var dir = (target.global_position - global_position).normalized()
		velocity = dir * speed
		if sprite:
			sprite.flip_h = (velocity.x > 0)
	else:
		velocity.x = 0
		velocity.y = sin(time_alive * 3.0) * 20.0
		
	move_and_slide()

func _find_target() -> void:
	var closest = null
	var min_dist = detection_range
	for p in [MiasmaManager.p1_node, MiasmaManager.p2_node]:
		if p and is_instance_valid(p):
			var d = global_position.distance_to(p.global_position)
			if d < min_dist:
				min_dist = d
				closest = p
	target = closest

func take_enemy_damage(dmg: float, source_id: int, hit_dir: float, _is_aoe: bool = false) -> void:
	current_hp -= dmg
	if sprite:
		sprite.modulate = Color(1.0, 0.2, 0.2)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.6, 0.2, 0.8), 0.2)
		
	if animator:
		animator.play("hurt", true)
		
	velocity.x = hit_dir * 150.0
	
	if current_hp <= 0:
		MiasmaManager.add_miasma(source_id, miasma_value)
		collision_layer = 0
		collision_mask = 0
		var death_tween = create_tween()
		death_tween.tween_property(self, "modulate:a", 0.0, 0.25)
		death_tween.tween_callback(queue_free)

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is PlayerBase:
		var dmg_taken = damage
		if body.has_method("is_blocking_active") and body.is_blocking_active():
			dmg_taken *= 0.2
			velocity.x = -velocity.x * 2.0
		body.apply_hit(dmg_taken, 5.0)
