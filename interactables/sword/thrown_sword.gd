class_name ThrownSword
extends CharacterBody2D

enum State {
	FLYING,
	FALLING,
	STUCK
}

const FLY_SPEED: float = 580.0
const MAX_RANGE: float = 560.0
const GRAVITY: float = 980.0

var state: State = State.FLYING
var direction: float = 1.0
var damage: int = 2
var distance_traveled: float = 0.0
var pickup_delay: float = 0.14
var bob_time: float = 0.0
var stuck_in_floor: bool = false
var _hit_targets: Array[Node] = []

@onready var sprite: Sprite2D = $Sprite2D
@onready var hit_area: Area2D = $HitArea
@onready var pickup_area: Area2D = $PickupArea
var prompt_label: Label = null


func launch(dir: float, dmg: int) -> void:
	direction = 1.0 if dir >= 0.0 else -1.0
	damage = maxi(1, dmg)
	state = State.FLYING


func _ready() -> void:
	add_to_group("thrown_sword")
	if sprite:
		sprite.flip_h = direction < 0.0
	if hit_area:
		hit_area.area_entered.connect(_on_hit_area_entered)
	if pickup_area:
		pickup_area.body_entered.connect(_on_pickup_body_entered)
	_create_prompt_label()


const CASTLE_FONT: Font = preload("res://assets/fonts/castle_pixel.fnt")

func _create_prompt_label() -> void:
	prompt_label = Label.new()
	prompt_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prompt_label.text = "ESPADA"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(-46, -38)
	prompt_label.size = Vector2(92, 20)
	prompt_label.add_theme_font_override("font", CASTLE_FONT)
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_color_override("font_color", Color("#b8ffe5"))
	prompt_label.add_theme_color_override("font_outline_color", Color("#120e17"))
	prompt_label.add_theme_constant_override("outline_size", 4)
	prompt_label.visible = false
	add_child(prompt_label)


func _physics_process(delta: float) -> void:
	if pickup_delay > 0.0:
		pickup_delay = maxf(0.0, pickup_delay - delta)

	match state:
		State.FLYING:
			velocity = Vector2(direction * FLY_SPEED, 0.0)
			var prev_x := global_position.x
			move_and_slide()
			distance_traveled += absf(global_position.x - prev_x)
			if sprite:
				sprite.rotation += direction * delta * 18.0
			_scan_hit_overlaps()
			if state != State.FLYING:
				return
			if is_on_wall():
				_enter_stuck(false)
			elif distance_traveled >= MAX_RANGE:
				state = State.FALLING

		State.FALLING:
			velocity.x = move_toward(velocity.x, 0.0, 420.0 * delta)
			velocity.y += GRAVITY * delta
			move_and_slide()
			if sprite:
				sprite.rotation += direction * delta * 10.0
			_scan_hit_overlaps()
			if is_on_floor() or is_on_wall():
				_enter_stuck(is_on_floor())

		State.STUCK:
			bob_time += delta
			if prompt_label:
				prompt_label.position.y = -38.0 + sin(bob_time * 4.5) * 2.5
			if sprite:
				var glow := 1.0 + sin(bob_time * 6.0) * 0.2
				sprite.modulate = Color(glow, glow, glow, 1.0)
			if pickup_delay <= 0.0 and pickup_area:
				for body in pickup_area.get_overlapping_bodies():
					if _try_retrieve(body):
						return


func _scan_hit_overlaps() -> void:
	if not hit_area:
		return
	for area in hit_area.get_overlapping_areas():
		_on_hit_area_entered(area)


func _on_hit_area_entered(area: Area2D) -> void:
	if state == State.STUCK or not (area is HurtBox):
		return
	var hurt_box := area as HurtBox
	if not (hurt_box.team in ["enemy", "destructible", "switch"]):
		return

	var target := area.get_parent()
	if target == null or target in _hit_targets:
		return
	_hit_targets.append(target)

	if target.has_method("take_hit"):
		target.take_hit(damage, global_position)
	elif target.has_method("hurt"):
		target.hurt()

	if hurt_box.team == "switch":
		_enter_stuck(false)


func _enter_stuck(in_floor: bool) -> void:
	if state == State.STUCK:
		return
	state = State.STUCK
	stuck_in_floor = in_floor
	velocity = Vector2.ZERO
	if hit_area:
		hit_area.set_deferred("monitoring", false)
	if sprite:
		sprite.flip_h = direction < 0.0
		sprite.rotation = (PI * 0.44 * direction) if in_floor else 0.0
	if prompt_label:
		prompt_label.visible = true
	if AudioManager:
		AudioManager.play_hit_sfx()


func _on_pickup_body_entered(body: Node2D) -> void:
	if state == State.STUCK and pickup_delay <= 0.0:
		_try_retrieve(body)


func _try_retrieve(body: Node2D) -> bool:
	if body == null or not body.has_method("retrieve_sword"):
		return false
	body.retrieve_sword()
	queue_free()
	return true
