class_name CastleDoor
extends Area2D

signal door_entered

var is_open: bool = false
var triggered: bool = false
var bob_time: float = 0.0
var locked_hint_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
var prompt_label: Label = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	if sprite:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, 32, 48)
	_create_prompt_label()


const CASTLE_FONT: Font = preload("res://assets/fonts/castle_pixel.fnt")

func _create_prompt_label() -> void:
	prompt_label = Label.new()
	prompt_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(-75, -46)
	prompt_label.size = Vector2(150, 22)
	prompt_label.scale = Vector2(0.42, 0.42)
	prompt_label.pivot_offset = Vector2(75, 11)
	prompt_label.add_theme_font_override("font", CASTLE_FONT)
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_color_override("font_outline_color", Color("#120e17"))
	prompt_label.add_theme_constant_override("outline_size", 5)
	prompt_label.visible = false
	add_child(prompt_label)


func open(silent: bool = false) -> void:
	if is_open:
		return
	is_open = true
	locked_hint_timer = 0.0
	if sprite:
		sprite.region_rect = Rect2(32, 0, 32, 48)
	if not silent and AudioManager:
		AudioManager.play_door_open_sfx()
	if prompt_label:
		prompt_label.text = "AVANÇAR ▶"
		prompt_label.modulate = Color("#ffd166")
		prompt_label.visible = true

	# If player is already standing inside doorway when the last enemy dies
	await get_tree().create_timer(0.25).timeout
	if not is_instance_valid(self) or triggered:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_enter_door()
			break


func _process(delta: float) -> void:
	bob_time += delta
	if prompt_label and prompt_label.visible:
		prompt_label.position.y = -44.0 + sin(bob_time * 4.5) * 2.0
	if locked_hint_timer > 0.0:
		locked_hint_timer -= delta
		if locked_hint_timer <= 0.0 and not is_open and prompt_label:
			prompt_label.visible = false


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if is_open:
		_enter_door()
	elif prompt_label:
		prompt_label.text = "Derrote os inimigos"
		prompt_label.modulate = Color("#ff8a8a")
		prompt_label.visible = true
		locked_hint_timer = 1.6


func _enter_door() -> void:
	if triggered:
		return
	triggered = true
	door_entered.emit()
