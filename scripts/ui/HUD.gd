class_name HUD
extends CanvasLayer

## HUD.gd
## Interface de Usuário (CanvasLayer) com Barras de HP, Miasma e Indicadores de Fase
## Sanguis & Miasma: O Preço da Cura (Godot 4.x)

@onready var p1_hp_bar: ProgressBar = $Control/P1Container/P1HPBar
@onready var p1_miasma_bar: ProgressBar = $Control/P1Container/P1MiasmaBar
@onready var p1_phase_label: Label = $Control/P1Container/P1PhaseLabel

@onready var p2_hp_bar: ProgressBar = $Control/P2Container/P2HPBar
@onready var p2_miasma_bar: ProgressBar = $Control/P2Container/P2MiasmaBar
@onready var p2_phase_label: Label = $Control/P2Container/P2PhaseLabel

@onready var vial_label: Label = $Control/VialContainer/VialLabel

@onready var status_banner: Label = $Control/StatusBanner

var transfusion_banner_timer: float = 0.0

@onready var victory_overlay: Panel = $Control/VictoryOverlay
@onready var game_over_overlay: Panel = $Control/GameOverOverlay

var game_ended: bool = false

func _ready() -> void:
	# Conectar aos Sinais do MiasmaManager
	MiasmaManager.hp_changed.connect(_on_hp_changed)
	MiasmaManager.miasma_changed.connect(_on_miasma_changed)
	MiasmaManager.player_downed.connect(_on_player_downed)
	MiasmaManager.player_revived.connect(_on_player_revived)
	MiasmaManager.transfusion_active.connect(_on_transfusion_active)
	MiasmaManager.purification_vial_collected.connect(_on_vial_count_changed)
	MiasmaManager.purification_vial_used.connect(_on_vial_used)
	
	_update_full_hud()

func _process(delta: float) -> void:
	if transfusion_banner_timer > 0.0:
		transfusion_banner_timer -= delta
		if transfusion_banner_timer <= 0.0 and status_banner:
			status_banner.visible = false
			
	# Reiniciar o jogo com R caso a partida tenha terminado
	if game_ended and Input.is_key_pressed(KEY_R):
		MiasmaManager.reset_game_state()
		get_tree().reload_current_scene()

func _update_full_hud() -> void:
	_on_hp_changed(1, MiasmaManager.p1_hp)
	_on_hp_changed(2, MiasmaManager.p2_hp)
	_on_miasma_changed(1, MiasmaManager.p1_miasma, MiasmaManager.p1_phase)
	_on_miasma_changed(2, MiasmaManager.p2_miasma, MiasmaManager.p2_phase)

func _on_hp_changed(player_id: int, new_hp: float) -> void:
	if player_id == 1 and p1_hp_bar:
		p1_hp_bar.value = new_hp
	elif player_id == 2 and p2_hp_bar:
		p2_hp_bar.value = new_hp

func _on_miasma_changed(player_id: int, new_miasma: float, phase: int) -> void:
	var phase_str = ""
	var color = Color.WHITE
	
	match phase:
		MiasmaManager.MiasmaPhase.PHASE_0_NORMAL:
			phase_str = "Fase 0: Estável"
			color = Color(0.7, 0.7, 0.7)
		MiasmaManager.MiasmaPhase.PHASE_1_MUTATION:
			phase_str = "Fase 1: Mutação Ativa"
			color = Color(0.4, 0.8, 0.3) # Verde Tóxico
		MiasmaManager.MiasmaPhase.PHASE_2_MAX_POWER:
			phase_str = "Fase 2: Poder Máximo (Necrose)"
			color = Color(0.8, 0.2, 0.9) # Roxo Intenso
		MiasmaManager.MiasmaPhase.PHASE_3_CRITICAL:
			phase_str = "CRÍTICO: Colapso!"
			color = Color(1.0, 0.1, 0.1) # Vermelho Alerta
			
	if player_id == 1:
		if p1_miasma_bar: p1_miasma_bar.value = new_miasma
		if p1_phase_label:
			p1_phase_label.text = phase_str
			p1_phase_label.modulate = color
	elif player_id == 2:
		if p2_miasma_bar: p2_miasma_bar.value = new_miasma
		if p2_phase_label:
			p2_phase_label.text = phase_str
			p2_phase_label.modulate = color

func _on_player_downed(player_id: int) -> void:
	if status_banner:
		var pname = "BALUARTE" if player_id == 1 else "CEIFADOR"
		status_banner.text = pname + " COLAPSOU! Pressione Interagir para Transfusão de Socorro!"
		status_banner.modulate = Color(1.0, 0.2, 0.2)
		status_banner.visible = true
		transfusion_banner_timer = 4.0
		
	# Checar se ambos colapsaram (Game Over)
	if MiasmaManager.p1_is_downed and MiasmaManager.p2_is_downed:
		trigger_game_over()

func _on_player_revived(player_id: int) -> void:
	if status_banner:
		var pname = "BALUARTE" if player_id == 1 else "CEIFADOR"
		status_banner.text = pname + " FOI PURIFICADO E REANIMADO!"
		status_banner.modulate = Color(0.3, 1.0, 0.4)
		status_banner.visible = true
		transfusion_banner_timer = 3.0

func _on_transfusion_active(giver_id: int, receiver_id: int, _rate: float) -> void:
	if AudioManager: AudioManager.play_transfusion_sfx()
	if status_banner:
		var gname = "P1" if giver_id == 1 else "P2"
		var rname = "P2" if giver_id == 1 else "P1"
		status_banner.text = "TRANSFUSÃO DE MIASMA: " + gname + " ---> " + rname
		status_banner.modulate = Color(0.7, 0.3, 0.9)
		status_banner.visible = true
		transfusion_banner_timer = 0.5

func _on_vial_count_changed(new_count: int) -> void:
	if vial_label:
		vial_label.text = "Frascos: " + str(new_count)

func _on_vial_used(new_count: int) -> void:
	_on_vial_count_changed(new_count)
	if status_banner:
		status_banner.text = "FRASCO USADO! MIASMA PURIFICADO!"
		status_banner.modulate = Color(0.2, 0.9, 1.0)
		status_banner.visible = true
		transfusion_banner_timer = 2.5

func trigger_victory() -> void:
	game_ended = true
	if victory_overlay: victory_overlay.visible = true
	if AudioManager: AudioManager.play_victory_sfx()

func trigger_game_over() -> void:
	game_ended = true
	if game_over_overlay: game_over_overlay.visible = true
	if AudioManager: AudioManager.play_game_over_sfx()

