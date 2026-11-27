class_name GameHUD
extends CanvasLayer

signal restart_level_requested
signal restart_game_requested
signal shop_buy_requested(item_id: String)
signal shop_closed
signal dialogue_finished

const HEART_FULL_TEX: Texture2D = preload("res://assets/sprites/ui/heart_full.png")
const HEART_EMPTY_TEX: Texture2D = preload("res://assets/sprites/ui/heart_empty.png")
const SHIELD_FULL_TEX: Texture2D = preload("res://assets/sprites/ui/shield_full.png")
const SHIELD_EMPTY_TEX: Texture2D = preload("res://assets/sprites/ui/shield_empty.png")
const COIN_ICON_TEX: Texture2D = preload("res://assets/sprites/ui/coin_icon.png")

@onready var hearts_box: HBoxContainer = $Root/TopLeftPanel/VBox/HeartsBox
@onready var shields_box: HBoxContainer = $Root/TopLeftPanel/VBox/ShieldsBox
@onready var coin_label: Label = $Root/TopLeftPanel/VBox/StatusRow/CoinLabel
@onready var sword_label: Label = $Root/TopLeftPanel/VBox/StatusRow/SwordLabel
@onready var level_label: Label = $Root/TopRightPanel/VBox/LevelLabel
@onready var enemies_label: Label = $Root/TopRightPanel/VBox/EnemiesLabel
@onready var banner_panel: PanelContainer = $Root/LevelBanner
@onready var banner_title: Label = $Root/LevelBanner/VBox/TitleLabel
@onready var banner_sub: Label = $Root/LevelBanner/VBox/SubtitleLabel
@onready var controls_hint: Label = $Root/ControlsHint
@onready var boss_panel: PanelContainer = $Root/BossPanel
@onready var boss_name_label: Label = $Root/BossPanel/VBox/BossName
@onready var boss_fill_rect: ColorRect = $Root/BossPanel/VBox/BossBarBG/BossFill
@onready var dialogue_panel: PanelContainer = $Root/DialoguePanel
@onready var dialogue_speaker: Label = $Root/DialoguePanel/VBox/SpeakerLabel
@onready var dialogue_body: Label = $Root/DialoguePanel/VBox/BodyLabel
@onready var dialogue_prompt: Label = $Root/DialoguePanel/VBox/PromptLabel
@onready var fade_rect: ColorRect = $Root/FadeRect
@onready var shop_overlay: ColorRect = $Root/ShopOverlay
@onready var shop_coins_label: Label = $Root/ShopOverlay/Center/Panel/VBox/ShopCoinsLabel
@onready var buy_dmg_btn: Button = $Root/ShopOverlay/Center/Panel/VBox/BuyDmgBtn
@onready var buy_hp_btn: Button = $Root/ShopOverlay/Center/Panel/VBox/BuyHpBtn
@onready var buy_shield_btn: Button = $Root/ShopOverlay/Center/Panel/VBox/BuyShieldBtn
@onready var buy_heal_btn: Button = $Root/ShopOverlay/Center/Panel/VBox/BuyHealBtn
@onready var close_shop_btn: Button = $Root/ShopOverlay/Center/Panel/VBox/CloseShopBtn
@onready var game_over_overlay: ColorRect = $Root/GameOverOverlay
@onready var victory_overlay: ColorRect = $Root/VictoryOverlay
@onready var victory_hearts_label: Label = $Root/VictoryOverlay/Center/Panel/VBox/HeartsResultLabel
@onready var pause_overlay: Control = $Root/PauseOverlay
@onready var pause_card: PanelContainer = $Root/PauseOverlay/Center/PauseCard
@onready var pause_settings_panel: SettingsPanel = $Root/PauseOverlay/Center/PauseSettingsPanel
@onready var resume_btn: Button = $Root/PauseOverlay/Center/PauseCard/VBox/ResumeBtn
@onready var pause_settings_btn: Button = $Root/PauseOverlay/Center/PauseCard/VBox/PauseSettingsBtn
@onready var exit_to_menu_btn: Button = $Root/PauseOverlay/Center/PauseCard/VBox/ExitToMenuBtn

var heart_icons: Array[TextureRect] = []
var shield_icons: Array[TextureRect] = []
var last_hearts: int = 3
var banner_timer: float = 0.0
var controls_timer: float = 0.0
var is_overlay_active: bool = false
var is_victory_state: bool = false
var is_shop_open: bool = false
var is_dialogue_open: bool = false
var is_paused: bool = false
var dialogue_queue: Array[Dictionary] = []
var dialogue_idx: int = 0
var prompt_blink_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hearts(3)
	_build_shields(2)
	if game_over_overlay:
		game_over_overlay.visible = false
	if victory_overlay:
		victory_overlay.visible = false
	if shop_overlay:
		shop_overlay.visible = false
	if dialogue_panel:
		dialogue_panel.visible = false
	if boss_panel:
		boss_panel.visible = false
	if pause_overlay:
		pause_overlay.visible = false
	if pause_settings_panel:
		pause_settings_panel.visible = false
		pause_settings_panel.back_requested.connect(_close_pause_settings)
	if resume_btn:
		resume_btn.pressed.connect(resume_game)
	if pause_settings_btn:
		pause_settings_btn.pressed.connect(_open_pause_settings)
	if exit_to_menu_btn:
		exit_to_menu_btn.pressed.connect(exit_game)
	if fade_rect:
		fade_rect.color.a = 0.0
	if buy_dmg_btn:
		buy_dmg_btn.pressed.connect(func(): shop_buy_requested.emit("damage"))
	if buy_hp_btn:
		buy_hp_btn.pressed.connect(func(): shop_buy_requested.emit("health"))
	if buy_shield_btn:
		buy_shield_btn.pressed.connect(func(): shop_buy_requested.emit("shield"))
	if buy_heal_btn:
		buy_heal_btn.pressed.connect(func(): shop_buy_requested.emit("heal"))
	if close_shop_btn:
		close_shop_btn.pressed.connect(close_shop)


func _build_hearts(max_hearts: int) -> void:
	if not hearts_box:
		return
	for child in hearts_box.get_children():
		child.queue_free()
	heart_icons.clear()

	for i in range(max_hearts):
		var icon := TextureRect.new()
		icon.texture = HEART_FULL_TEX
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(36, 36)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.pivot_offset = Vector2(18, 18)
		hearts_box.add_child(icon)
		heart_icons.append(icon)


func _build_shields(max_sh: int) -> void:
	if not shields_box:
		return
	for child in shields_box.get_children():
		child.queue_free()
	shield_icons.clear()

	for i in range(max_sh):
		var icon := TextureRect.new()
		icon.texture = SHIELD_FULL_TEX
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(28, 28)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		shields_box.add_child(icon)
		shield_icons.append(icon)


func update_hearts(current_hearts: int, max_hearts: int = 3) -> void:
	if heart_icons.size() != max_hearts:
		_build_hearts(max_hearts)

	var damaged := current_hearts < last_hearts
	var healed := current_hearts > last_hearts
	last_hearts = current_hearts

	for i in range(heart_icons.size()):
		var icon := heart_icons[i]
		var filled := i < current_hearts
		icon.texture = HEART_FULL_TEX if filled else HEART_EMPTY_TEX
		if healed and filled and i == current_hearts - 1:
			var tw := icon.create_tween()
			icon.scale = Vector2(1.28, 1.28)
			tw.tween_property(icon, "scale", Vector2.ONE, 0.22)

	if damaged and hearts_box:
		var origin_x := hearts_box.position.x
		var tw := hearts_box.create_tween()
		tw.tween_property(hearts_box, "position:x", origin_x - 6.0, 0.04)
		tw.tween_property(hearts_box, "position:x", origin_x + 6.0, 0.04)
		tw.tween_property(hearts_box, "position:x", origin_x - 4.0, 0.04)
		tw.tween_property(hearts_box, "position:x", origin_x, 0.04)


func update_shields(current_shield: int, max_shield: int = 2) -> void:
	if shield_icons.size() != max_shield:
		_build_shields(max_shield)
	for i in range(shield_icons.size()):
		shield_icons[i].texture = SHIELD_FULL_TEX if i < current_shield else SHIELD_EMPTY_TEX


func update_coins(amount: int) -> void:
	if coin_label:
		coin_label.text = "%d" % amount
	if shop_coins_label:
		shop_coins_label.text = "Suas Moedas: %d" % amount


func update_sword_state(has_sword: bool) -> void:
	if not sword_label:
		return
	if has_sword:
		sword_label.text = "Espada: Pronta"
		sword_label.modulate = Color("#d8e2f0")
	else:
		sword_label.text = "Sem Espada!"
		sword_label.modulate = Color("#ffd166")


func set_level_info(level_num: int, total_levels: int, title: String, subtitle: String, hint_text: String) -> void:
	is_overlay_active = false
	is_victory_state = false
	is_shop_open = false
	is_dialogue_open = false
	is_paused = false
	get_tree().paused = false
	if pause_overlay:
		pause_overlay.visible = false
	if game_over_overlay:
		game_over_overlay.visible = false
	if victory_overlay:
		victory_overlay.visible = false
	if shop_overlay:
		shop_overlay.visible = false
	if dialogue_panel:
		dialogue_panel.visible = false

	if level_label:
		level_label.text = "FASE %d / %d  •  %s" % [level_num, total_levels, title]

	if banner_panel and banner_title and banner_sub:
		banner_title.text = title.to_upper()
		banner_sub.text = subtitle
		banner_panel.visible = true
		banner_panel.modulate.a = 1.0
		banner_timer = 2.6

	if controls_hint:
		var has_hint := hint_text != ""
		controls_hint.text = hint_text
		controls_hint.visible = has_hint
		controls_hint.modulate.a = 1.0
		controls_timer = 9.0 if has_hint else 0.0


func show_boss_callout(title_text: String, sub_text: String, title_col: Color = Color("#c084fc")) -> void:
	if banner_panel and banner_title and banner_sub:
		banner_title.text = title_text
		banner_title.add_theme_color_override("font_color", title_col)
		banner_sub.text = sub_text
		banner_panel.visible = true
		banner_panel.modulate.a = 1.0
		banner_timer = 2.4


func update_stage_objective(enemies_count: int, stage_type: String, door_is_open: bool, horde_wave: int = 0) -> void:
	if not enemies_label:
		return
	if door_is_open:
		enemies_label.text = "PORTA ABERTA!"
		enemies_label.modulate = Color("#ffd166")
	elif horde_wave > 0:
		enemies_label.text = "Horda %d/3: %d" % [horde_wave, enemies_count]
		enemies_label.modulate = Color("#c084fc")
	elif stage_type == "intro":
		enemies_label.text = "Quebre uma caixa!"
		enemies_label.modulate = Color("#ffd166")
	elif stage_type == "intro_throw":
		enemies_label.text = "Ative o cristal!"
		enemies_label.modulate = Color("#38d9a9")
	elif enemies_count > 0:
		enemies_label.text = "Inimigos: %d" % enemies_count
		enemies_label.modulate = Color("#e2d9f3")
	else:
		enemies_label.text = "PORTA ABERTA!"
		enemies_label.modulate = Color("#ffd166")


func setup_boss_bar(boss_title: String, hp: int, max_hp: int) -> void:
	if not boss_panel:
		return
	boss_panel.visible = true
	update_boss_bar(hp, max_hp, boss_title)


func update_boss_bar(hp: int, max_hp: int, label_override: String = "") -> void:
	if not boss_panel:
		return
	if boss_name_label:
		if label_override != "":
			boss_name_label.text = label_override
		else:
			boss_name_label.text = "TIRANO CORROMPIDO  (%d / %d)" % [hp, max_hp]
	if boss_fill_rect and max_hp > 0:
		var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
		boss_fill_rect.anchor_right = ratio
	if hp <= 0:
		boss_panel.visible = false


func hide_boss_bar() -> void:
	if boss_panel:
		boss_panel.visible = false


func start_dialogue(lines: Array[Dictionary]) -> void:
	if lines.is_empty():
		dialogue_finished.emit()
		return
	dialogue_queue = lines
	dialogue_idx = 0
	is_dialogue_open = true
	if dialogue_panel:
		dialogue_panel.visible = true
	_render_dialogue_line()


func advance_dialogue() -> void:
	if not is_dialogue_open:
		return
	dialogue_idx += 1
	if dialogue_idx >= dialogue_queue.size():
		is_dialogue_open = false
		if dialogue_panel:
			dialogue_panel.visible = false
		dialogue_finished.emit()
	else:
		_render_dialogue_line()


func _render_dialogue_line() -> void:
	var line := dialogue_queue[dialogue_idx]
	if dialogue_speaker:
		dialogue_speaker.text = line.get("speaker", "")
		dialogue_speaker.modulate = line.get("color", Color("#ffd166"))
	if dialogue_body:
		dialogue_body.text = line.get("text", "")


func open_shop(coins: int, dmg_lv: int, hp_lv: int, shield_lv: int, current_hearts: int, max_hearts: int, dmg_costs: Array, hp_costs: Array, shield_costs: Array, heal_cost: int) -> void:
	is_shop_open = true
	if shop_overlay:
		shop_overlay.visible = true
	refresh_shop(coins, dmg_lv, hp_lv, shield_lv, current_hearts, max_hearts, dmg_costs, hp_costs, shield_costs, heal_cost)


func refresh_shop(coins: int, dmg_lv: int, hp_lv: int, shield_lv: int, current_hearts: int, max_hearts: int, dmg_costs: Array, hp_costs: Array, shield_costs: Array, heal_cost: int) -> void:
	update_coins(coins)
	if buy_dmg_btn:
		if dmg_lv >= dmg_costs.size():
			buy_dmg_btn.text = "[1] Lâmina Afiada (MÁXIMO)"
			buy_dmg_btn.disabled = true
		else:
			var c: int = dmg_costs[dmg_lv]
			buy_dmg_btn.text = "[1] Lâmina Afiada (+1 Dano) — %d Moedas (Nív %d/3)" % [c, dmg_lv + 1]
			buy_dmg_btn.disabled = coins < c

	if buy_hp_btn:
		if hp_lv >= hp_costs.size():
			buy_hp_btn.text = "[2] Vigor Rubro (MÁXIMO)"
			buy_hp_btn.disabled = true
		else:
			var c: int = hp_costs[hp_lv]
			buy_hp_btn.text = "[2] Vigor Rubro (+1 Vida Máx) — %d Moedas (Nív %d/3)" % [c, hp_lv + 1]
			buy_hp_btn.disabled = coins < c

	if buy_shield_btn:
		if shield_lv >= shield_costs.size():
			buy_shield_btn.text = "[3] Égide de Ferro (MÁXIMO)"
			buy_shield_btn.disabled = true
		else:
			var c: int = shield_costs[shield_lv]
			buy_shield_btn.text = "[3] Égide de Ferro (+1 Escudo) — %d Moedas (Nív %d/3)" % [c, shield_lv + 1]
			buy_shield_btn.disabled = coins < c

	if buy_heal_btn:
		if current_hearts >= max_hearts:
			buy_heal_btn.text = "[4] Elixir Rubro (Vida Cheia)"
			buy_heal_btn.disabled = true
		else:
			buy_heal_btn.text = "[4] Elixir Rubro (+1 Coração) — %d Moedas" % heal_cost
			buy_heal_btn.disabled = coins < heal_cost


func close_shop() -> void:
	if not is_shop_open:
		return
	is_shop_open = false
	if shop_overlay:
		shop_overlay.visible = false
	shop_closed.emit()


func show_game_over() -> void:
	if is_paused:
		is_paused = false
		get_tree().paused = false
		if pause_overlay:
			pause_overlay.visible = false
	close_shop()
	is_dialogue_open = false
	if dialogue_panel:
		dialogue_panel.visible = false
	is_overlay_active = true
	is_victory_state = false
	if game_over_overlay:
		game_over_overlay.visible = true
	if AudioManager:
		AudioManager.play_game_over_sfx()


func show_victory(remaining_hearts: int, max_hearts: int, coins_left: int) -> void:
	if is_paused:
		is_paused = false
		get_tree().paused = false
		if pause_overlay:
			pause_overlay.visible = false
	close_shop()
	is_dialogue_open = false
	if dialogue_panel:
		dialogue_panel.visible = false
	is_overlay_active = true
	is_victory_state = true
	hide_boss_bar()
	if victory_hearts_label:
		victory_hearts_label.text = "Corações: %d / %d   •   Moedas: %d" % [remaining_hearts, max_hearts, coins_left]
	if victory_overlay:
		victory_overlay.visible = true
	if AudioManager:
		AudioManager.play_victory_sfx()


func pause_game() -> void:
	if is_overlay_active or is_paused:
		return
	is_paused = true
	get_tree().paused = true
	if pause_card:
		pause_card.visible = true
	if pause_settings_panel:
		pause_settings_panel.visible = false
	if pause_overlay:
		pause_overlay.visible = true
	if AudioManager:
		AudioManager.play_ui_click_sfx()


func resume_game() -> void:
	if not is_paused:
		return
	is_paused = false
	if pause_overlay:
		pause_overlay.visible = false
	if pause_settings_panel:
		pause_settings_panel.visible = false
	get_tree().paused = false
	if AudioManager:
		AudioManager.play_ui_click_sfx()


func toggle_pause() -> void:
	if is_paused:
		resume_game()
	else:
		pause_game()


func _open_pause_settings() -> void:
	if AudioManager:
		AudioManager.play_ui_click_sfx()
	if pause_card:
		pause_card.visible = false
	if pause_settings_panel:
		pause_settings_panel.refresh_from_settings()
		pause_settings_panel.visible = true


func _close_pause_settings() -> void:
	if pause_settings_panel:
		pause_settings_panel.visible = false
	if pause_card:
		pause_card.visible = true


func exit_game() -> void:
	if AudioManager:
		AudioManager.play_ui_click_sfx()
	is_paused = false
	get_tree().paused = false
	get_tree().quit()


func fade_to(target_alpha: float, duration: float = 0.25) -> void:
	if not fade_rect:
		return
	var tw := fade_rect.create_tween()
	tw.tween_property(fade_rect, "color:a", target_alpha, duration)
	await tw.finished


func _unhandled_input(event: InputEvent) -> void:
	if is_paused:
		if event is InputEventKey and event.pressed and not event.echo:
			var pk := (event as InputEventKey).keycode
			if pk == KEY_ESCAPE or pk == KEY_P:
				if pause_settings_panel and pause_settings_panel.visible:
					if AudioManager:
						AudioManager.play_ui_click_sfx()
					_close_pause_settings()
				else:
					resume_game()
				get_viewport().set_input_as_handled()
		return

	if is_overlay_active:
		return

	if is_shop_open:
		if event is InputEventKey and event.pressed and not event.echo:
			var sk := (event as InputEventKey).keycode
			match sk:
				KEY_1:
					shop_buy_requested.emit("damage")
				KEY_2:
					shop_buy_requested.emit("health")
				KEY_3:
					shop_buy_requested.emit("shield")
				KEY_4:
					shop_buy_requested.emit("heal")
				KEY_ESCAPE, KEY_E:
					close_shop()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_ESCAPE or k == KEY_P:
			pause_game()
			get_viewport().set_input_as_handled()
			return

	if is_dialogue_open:
		if event is InputEventKey and event.pressed and not event.echo:
			var dk := (event as InputEventKey).keycode
			if dk in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_J, KEY_Z]:
				advance_dialogue()
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:
			advance_dialogue()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if is_paused:
		return
	if is_dialogue_open and dialogue_prompt:
		prompt_blink_time += delta
		dialogue_prompt.modulate.a = 0.55 + sin(prompt_blink_time * 5.0) * 0.45

	if banner_timer > 0.0:
		banner_timer -= delta
		if banner_timer <= 0.0 and banner_panel:
			var tw := banner_panel.create_tween()
			tw.tween_property(banner_panel, "modulate:a", 0.0, 0.4)
			tw.tween_callback(func():
				banner_panel.visible = false
				if banner_title:
					banner_title.add_theme_color_override("font_color", Color("#ffd166"))
			)

	if controls_timer > 0.0:
		controls_timer -= delta
		if controls_timer <= 0.0 and controls_hint:
			var tw := controls_hint.create_tween()
			tw.tween_property(controls_hint, "modulate:a", 0.0, 0.5)
			tw.tween_callback(func(): controls_hint.visible = false)

	if is_overlay_active:
		if Input.is_key_pressed(KEY_R) or Input.is_key_pressed(KEY_ENTER):
			is_overlay_active = false
			if is_victory_state:
				restart_game_requested.emit()
			else:
				restart_level_requested.emit()
		elif not is_victory_state and Input.is_key_pressed(KEY_T):
			is_overlay_active = false
			restart_game_requested.emit()
