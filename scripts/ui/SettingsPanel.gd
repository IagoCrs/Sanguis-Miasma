class_name SettingsPanel
extends PanelContainer

signal back_requested

@onready var res_prev_btn: Button = $VBox/ResRow/ResPrevBtn
@onready var res_value_label: Label = $VBox/ResRow/ResValueLabel
@onready var res_next_btn: Button = $VBox/ResRow/ResNextBtn
@onready var vol_down_btn: Button = $VBox/VolRow/VolDownBtn
@onready var volume_slider: HSlider = $VBox/VolRow/VolumeSlider
@onready var vol_up_btn: Button = $VBox/VolRow/VolUpBtn
@onready var vol_value_label: Label = $VBox/VolRow/VolValueLabel
@onready var back_btn: Button = $VBox/BackBtn


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if res_prev_btn:
		res_prev_btn.pressed.connect(func(): _cycle_resolution(-1))
	if res_next_btn:
		res_next_btn.pressed.connect(func(): _cycle_resolution(1))
	if vol_down_btn:
		vol_down_btn.pressed.connect(func(): _nudge_volume(-0.1))
	if vol_up_btn:
		vol_up_btn.pressed.connect(func(): _nudge_volume(0.1))
	if volume_slider:
		volume_slider.value_changed.connect(_on_slider_changed)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	refresh_from_settings()


func refresh_from_settings() -> void:
	if not AudioManager:
		return
	var idx := clampi(AudioManager.resolution_index, 0, AudioManager.RESOLUTION_LABELS.size() - 1)
	if res_value_label:
		res_value_label.text = AudioManager.RESOLUTION_LABELS[idx]
	var pct := int(round(AudioManager.music_volume * 100.0))
	if volume_slider:
		volume_slider.set_value_no_signal(float(pct))
	if vol_value_label:
		vol_value_label.text = "%d%%" % pct


func _cycle_resolution(delta_idx: int) -> void:
	if AudioManager:
		AudioManager.play_ui_click_sfx()
		AudioManager.apply_resolution(AudioManager.resolution_index + delta_idx)
	refresh_from_settings()


func _nudge_volume(delta_vol: float) -> void:
	if AudioManager:
		AudioManager.set_music_volume(AudioManager.music_volume + delta_vol)
		AudioManager.play_ui_click_sfx()
	refresh_from_settings()


func _on_slider_changed(val: float) -> void:
	if AudioManager:
		AudioManager.set_music_volume(val / 100.0)
	if vol_value_label:
		vol_value_label.text = "%d%%" % int(round(val))


func _on_back_pressed() -> void:
	if AudioManager:
		AudioManager.play_ui_click_sfx()
	back_requested.emit()
