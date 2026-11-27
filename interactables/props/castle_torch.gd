extends Node2D

var flicker_time: float = 0.0
@onready var glow: Polygon2D = $Glow


func _ready() -> void:
	flicker_time = randf() * 10.0


func _process(delta: float) -> void:
	flicker_time += delta
	if glow:
		var pulse := 0.92 + sin(flicker_time * 9.0) * 0.08 + sin(flicker_time * 17.0) * 0.04
		glow.scale = Vector2(pulse, pulse)
		glow.color.a = 0.14 + sin(flicker_time * 11.0) * 0.03
