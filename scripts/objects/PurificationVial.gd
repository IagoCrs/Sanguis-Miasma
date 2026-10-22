class_name PurificationVial
extends Area2D

## PurificationVial.gd - Frasco de Purificação Coletável
## Sanguis & Miasma: O Preço da Cura

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Animação procedural de flutuação suave
	var tween = create_tween().set_loops()
	tween.tween_property(self, "position:y", position.y - 4.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", position.y + 4.0, 0.8).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerBase:
		if AudioManager: AudioManager.play_vial_sfx()
		MiasmaManager.add_purification_vial()
		_play_collect_effect()

func _play_collect_effect() -> void:
	# Efeito visual de brilho verde-azul purificador
	collision_mask = 0
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.15)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
