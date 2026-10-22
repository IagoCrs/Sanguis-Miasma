extends Node

## AudioManager.gd
## Singleton Global de Áudio e Síntese de Efeitos Sonoros Góticos (Godot 4.x)
## Sanguis & Miasma: O Preço da Cura

var audio_player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var sample_rate: float = 22050.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_generator()

func _setup_audio_generator() -> void:
	audio_player = AudioStreamPlayer.new()
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = sample_rate
	generator.buffer_length = 0.1
	audio_player.stream = generator
	add_child(audio_player)
	audio_player.play()
	playback = audio_player.get_stream_playback()

func _generate_tone(freq: float, duration: float, volume: float = 0.3, wave_type: String = "sine") -> void:
	if playback == null: return
	
	var num_samples = int(sample_rate * duration)
	var phase: float = 0.0
	var phase_increment = freq / sample_rate
	
	for i in range(num_samples):
		var env = 1.0 - (float(i) / num_samples) # Envelope de desvanecimento (Fade out)
		var sample: float = 0.0
		
		if wave_type == "sine":
			sample = sin(phase * TAU) * volume * env
		elif wave_type == "square":
			sample = (1.0 if sin(phase * TAU) > 0.0 else -1.0) * volume * env * 0.6
		elif wave_type == "saw":
			sample = (fmod(phase, 1.0) * 2.0 - 1.0) * volume * env * 0.5
		elif wave_type == "noise":
			sample = (randf() * 2.0 - 1.0) * volume * env * 0.4
			
		var vector_sample = Vector2(sample, sample)
		if playback.can_push_buffer(1):
			playback.push_frame(vector_sample)
		phase = fmod(phase + phase_increment, 1.0)

# Efeitos Sonoros Públicos chamados pelo Jogo
func play_jump_sfx() -> void:
	_generate_tone(320.0, 0.12, 0.25, "sine")

func play_attack_sfx() -> void:
	_generate_tone(180.0, 0.08, 0.3, "saw")

func play_shield_block_sfx() -> void:
	_generate_tone(440.0, 0.15, 0.35, "square")

func play_dash_sfx() -> void:
	_generate_tone(120.0, 0.14, 0.3, "noise")

func play_hit_sfx() -> void:
	_generate_tone(90.0, 0.12, 0.4, "saw")

func play_vial_sfx() -> void:
	_generate_tone(587.33, 0.2, 0.3, "sine") # Nota Re5 celestial

func play_transfusion_sfx() -> void:
	_generate_tone(350.0, 0.08, 0.2, "sine")

func play_boss_stagger_sfx() -> void:
	_generate_tone(150.0, 0.4, 0.45, "square")

func play_victory_sfx() -> void:
	_generate_tone(523.25, 0.3, 0.4, "sine") # Dó
	_generate_tone(659.25, 0.4, 0.4, "sine") # Mi
	_generate_tone(783.99, 0.5, 0.4, "sine") # Sol

func play_game_over_sfx() -> void:
	_generate_tone(164.81, 0.4, 0.45, "saw") # Mi grave
	_generate_tone(130.81, 0.6, 0.45, "saw") # Dó grave
