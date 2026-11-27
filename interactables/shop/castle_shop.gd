class_name CastleShop
extends Area2D

signal shop_interact_requested

var player_inside: bool = false
var bob_time: float = 0.0

var prompt_label: Label = null


func _ready() -> void:
	add_to_group("castle_shop")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_create_prompt()


const CASTLE_FONT: Font = preload("res://assets/fonts/castle_pixel.fnt")

func _create_prompt() -> void:
	prompt_label = Label.new()
	prompt_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prompt_label.text = "[E] Loja do Mercador"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(-100, -76)
	prompt_label.size = Vector2(200, 22)
	prompt_label.add_theme_font_override("font", CASTLE_FONT)
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_color_override("font_color", Color("#ffd166"))
	prompt_label.add_theme_color_override("font_outline_color", Color("#120e17"))
	prompt_label.add_theme_constant_override("outline_size", 4)
	prompt_label.visible = false
	add_child(prompt_label)


func _process(delta: float) -> void:
	bob_time += delta
	if prompt_label and prompt_label.visible:
		prompt_label.position.y = -76.0 + sin(bob_time * 4.2) * 3.0
	if player_inside and Input.is_action_just_pressed("interact"):
		shop_interact_requested.emit()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		if prompt_label:
			prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		if prompt_label:
			prompt_label.visible = false
