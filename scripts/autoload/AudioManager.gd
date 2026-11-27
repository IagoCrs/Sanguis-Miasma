extends Node

## AudioManager.gd
## Singleton Global de Áudio e Síntese de Efeitos Sonoros Góticos (Godot 4.x)
## Sanguis & Miasma: O Preço da Cura

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(0, 0), # Tela Cheia
]
const RESOLUTION_LABELS: Array[String] = [
	"1280 x 720 (HD)",
	"1600 x 900 (HD+)",
	"1920 x 1080 (Full HD)",
	"Tela Cheia",
]

var audio_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var sample_rate: float = 22050.0
var current_music_track: String = ""
var music_tween: Tween = null
var resolution_index: int = 0
var music_volume: float = 0.8
var base_music_db: float = -9.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_generator()
	_setup_music_player()

func _setup_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)

func play_ambient_music() -> void:
	_play_music("res://assets/audio/music/ambient_castle.mp3", -9.0)

func play_boss_music() -> void:
	_play_music("res://assets/audio/music/boss_fight.mp3", -7.0)

func stop_music() -> void:
	current_music_track = ""
	if music_tween and music_tween.is_valid():
		music_tween.kill()
	if music_player:
		music_player.stop()

func get_effective_music_db(base_db: float = base_music_db) -> float:
	if music_volume <= 0.001:
		return -80.0
	return base_db + linear_to_db(clampf(music_volume, 0.001, 1.0))

func set_music_volume(linear_val: float) -> void:
	music_volume = clampf(linear_val, 0.0, 1.0)
	if music_tween and music_tween.is_valid():
		music_tween.kill()
	if music_player:
		music_player.volume_db = get_effective_music_db()

func apply_resolution(idx: int) -> void:
	resolution_index = posmod(idx, RESOLUTIONS.size())
	if DisplayServer.get_name() == "headless":
		return
	var target_size: Vector2i = RESOLUTIONS[resolution_index]
	if target_size == Vector2i.ZERO:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(target_size)
		var screen := DisplayServer.window_get_current_screen()
		var screen_pos := DisplayServer.screen_get_position(screen)
		var screen_size := DisplayServer.screen_get_size(screen)
		var centered := screen_pos + (screen_size - target_size) / 2
		DisplayServer.window_set_position(Vector2i(maxi(screen_pos.x, centered.x), maxi(screen_pos.y, centered.y)))

func _play_music(path: String, target_db: float) -> void:
	if music_player == null:
		return
	base_music_db = target_db
	var final_db := get_effective_music_db(target_db)
	if current_music_track == path and music_player.playing:
		music_player.volume_db = final_db
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	current_music_track = path
	if music_tween and music_tween.is_valid():
		music_tween.kill()
	music_player.stream = stream
	if music_volume <= 0.001:
		music_player.volume_db = -80.0
		music_player.play()
		return
	music_player.volume_db = minf(-28.0, final_db)
	music_player.play()
	music_tween = create_tween()
	music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	music_tween.tween_property(music_player, "volume_db", final_db, 0.8)

func _setup_audio_generator() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
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

func play_crate_break_sfx() -> void:
	_generate_tone(140.0, 0.08, 0.35, "noise")
	_generate_tone(95.0, 0.12, 0.3, "square")

func play_heart_pickup_sfx() -> void:
	_generate_tone(523.25, 0.09, 0.28, "sine")
	_generate_tone(783.99, 0.16, 0.3, "sine")

func play_door_open_sfx() -> void:
	_generate_tone(110.0, 0.18, 0.3, "square")
	_generate_tone(392.0, 0.22, 0.28, "sine")

func play_player_hurt_sfx() -> void:
	_generate_tone(115.0, 0.12, 0.4, "saw")
	_generate_tone(75.0, 0.14, 0.35, "square")

func play_enemy_die_sfx() -> void:
	_generate_tone(190.0, 0.07, 0.3, "saw")
	_generate_tone(95.0, 0.1, 0.25, "noise")

func play_coin_sfx() -> void:
	_generate_tone(987.77, 0.06, 0.22, "sine")
	_generate_tone(1318.51, 0.12, 0.24, "sine")

func play_sword_throw_sfx() -> void:
	_generate_tone(360.0, 0.07, 0.26, "noise")
	_generate_tone(240.0, 0.09, 0.22, "saw")

func play_sword_pickup_sfx() -> void:
	_generate_tone(440.0, 0.07, 0.24, "sine")
	_generate_tone(659.25, 0.11, 0.26, "sine")

func play_switch_sfx() -> void:
	_generate_tone(622.25, 0.08, 0.28, "square")
	_generate_tone(880.0, 0.14, 0.26, "sine")

func play_gate_open_sfx() -> void:
	_generate_tone(95.0, 0.22, 0.32, "square")
	_generate_tone(140.0, 0.18, 0.25, "noise")

func play_shop_buy_sfx() -> void:
	_generate_tone(587.33, 0.08, 0.28, "sine")
	_generate_tone(880.0, 0.16, 0.3, "sine")

func play_shop_deny_sfx() -> void:
	_generate_tone(150.0, 0.12, 0.26, "saw")

func play_spit_sfx() -> void:
	_generate_tone(420.0, 0.06, 0.22, "noise")
	_generate_tone(280.0, 0.08, 0.24, "sine")

func play_boss_roar_sfx() -> void:
	_generate_tone(95.0, 0.28, 0.42, "saw")
	_generate_tone(72.0, 0.35, 0.38, "square")

func play_axe_throw_sfx() -> void:
	_generate_tone(210.0, 0.10, 0.32, "noise")
	_generate_tone(145.0, 0.14, 0.30, "saw")

func play_ui_click_sfx() -> void:
	_generate_tone(520.0, 0.05, 0.22, "square")
	_generate_tone(780.0, 0.07, 0.20, "sine")
