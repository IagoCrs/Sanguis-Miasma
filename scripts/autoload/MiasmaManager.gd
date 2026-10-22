extends Node

## MiasmaManager.gd
## Singleton Global de Gerenciamento de Miasma e Estado Cooperativo
## Sanguis & Miasma: O Preço da Cura (Godot 4.x)

# Sinais do Sistema
signal hp_changed(player_id: int, new_hp: float)
signal miasma_changed(player_id: int, new_miasma: float, new_phase: int)
signal player_downed(player_id: int)
signal player_revived(player_id: int)
signal transfusion_active(giver_id: int, receiver_id: int, rate: float)
signal purification_vial_collected(new_count: int)
signal purification_vial_used(new_count: int)

# Enums de Fase de Corrupção por Miasma
enum MiasmaPhase {
	PHASE_0_NORMAL = 0,   # 0% - 30%
	PHASE_1_MUTATION = 1, # 31% - 70%
	PHASE_2_MAX_POWER = 2,# 71% - 99%
	PHASE_3_CRITICAL = 3  # 100% (Colapso Biológico)
}

# Dados dos Jogadores (P1 = Baluarte, P2 = Ceifador)
var p1_hp: float = 100.0
var p1_miasma: float = 0.0
var p1_phase: MiasmaPhase = MiasmaPhase.PHASE_0_NORMAL
var p1_is_downed: bool = false

var p2_hp: float = 100.0
var p2_miasma: float = 0.0
var p2_phase: MiasmaPhase = MiasmaPhase.PHASE_0_NORMAL
var p2_is_downed: bool = false

# Inventário Compartilhado
var shared_vials_count: int = 0

# Parâmetros de Balanceamento
const MAX_HP: float = 100.0
const MAX_MIASMA: float = 100.0
const NECROSIS_DAMAGE_PER_SEC: float = 4.0 # Dano continuo na Fase 2
const TRANSFUSION_RATE_PER_SEC: float = 20.0 # Velocidade de transfusão entre jogadores
const TRANSFUSION_RADIUS: float = 64.0 # Distância máxima entre jogadores para transfusão

# Referências dos nós dos jogadores no mapa (atribuídos ao carregar)
var p1_node: CharacterBody2D = null
var p2_node: CharacterBody2D = null
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_default_input_map()
	reset_game_state()

func _process(delta: float) -> void:
	_process_phase_effects(delta)
	_process_transfusion_check(delta)
	_process_vial_input()

# Inicialização e Registro dinâmico de Teclas de Atalho (InputMap Fallback)
func _setup_default_input_map() -> void:
	var inputs = {
		# Player 1 (Baluarte - Tank: WASD + Espaço + J/K/L + Q/E)
		"p1_left": [KEY_A],
		"p1_right": [KEY_D],
		"p1_up": [KEY_W],
		"p1_down": [KEY_S],
		"p1_jump": [KEY_W, KEY_SPACE, KEY_K],
		"p1_attack": [KEY_J, KEY_F],
		"p1_shield": [KEY_L, KEY_K, KEY_SHIFT],
		"p1_interact": [KEY_E],
		"p1_use_vial": [KEY_Q],
		
		# Player 2 (Ceifador - Ágil: Setas / Numpad / ZXC)
		"p2_left": [KEY_LEFT],
		"p2_right": [KEY_RIGHT],
		"p2_up": [KEY_UP],
		"p2_down": [KEY_DOWN],
		"p2_jump": [KEY_UP, KEY_KP_2, KEY_KP_0, KEY_M],
		"p2_attack": [KEY_KP_1, KEY_KP_4, KEY_SLASH, KEY_COMMA, KEY_Z],
		"p2_dash": [KEY_KP_3, KEY_KP_5, KEY_PERIOD, KEY_X],
		"p2_interact": [KEY_KP_0, KEY_DOWN, KEY_C],
		"p2_use_vial": [KEY_PAGEDOWN, KEY_KP_7, KEY_V]
	}
	
	for action_name in inputs.keys():
		if InputMap.has_action(action_name):
			InputMap.erase_action(action_name)
		InputMap.add_action(action_name)
		for key_code in inputs[action_name]:
			var event = InputEventKey.new()
			event.keycode = key_code
			InputMap.action_add_event(action_name, event)

# Reiniciar Estado
func reset_game_state() -> void:
	p1_hp = MAX_HP
	p1_miasma = 0.0
	p1_phase = MiasmaPhase.PHASE_0_NORMAL
	p1_is_downed = false
	
	p2_hp = MAX_HP
	p2_miasma = 0.0
	p2_phase = MiasmaPhase.PHASE_0_NORMAL
	p2_is_downed = false

# Atribuição de Dano
func take_damage(player_id: int, amount: float, miasma_buildup: float = 0.0) -> void:
	if player_id == 1:
		if p1_is_downed: return
		# Redução de dano se P1 estiver bloqueando com escudo
		if p1_node and p1_node.has_method("is_blocking_active") and p1_node.is_blocking_active():
			amount *= 0.25 # 75% de redução de dano
			miasma_buildup *= 0.5
		
		# Redução pela Armadura da Fase 1 da Mutação
		if p1_phase >= MiasmaPhase.PHASE_1_MUTATION:
			amount *= 0.75 # 25% extra de armadura física
			
		p1_hp = clamp(p1_hp - amount, 0.0, MAX_HP)
		hp_changed.emit(1, p1_hp)
		
		if miasma_buildup > 0.0:
			add_miasma(1, miasma_buildup)
			
		if p1_hp <= 0.0:
			_set_player_downed(1)
			
	elif player_id == 2:
		if p2_is_downed: return
		# P2 invulnerável durante dash
		if p2_node and p2_node.has_method("is_dashing_active") and p2_node.is_dashing_active():
			return # Esquiva completa
			
		p2_hp = clamp(p2_hp - amount, 0.0, MAX_HP)
		hp_changed.emit(2, p2_hp)
		
		if miasma_buildup > 0.0:
			add_miasma(2, miasma_buildup)
			
		if p2_hp <= 0.0:
			_set_player_downed(2)

# Adicionar Corrupção por Miasma
func add_miasma(player_id: int, amount: float) -> void:
	if player_id == 1:
		if p1_is_downed: return
		p1_miasma = clamp(p1_miasma + amount, 0.0, MAX_MIASMA)
		p1_phase = _calculate_phase(p1_miasma)
		miasma_changed.emit(1, p1_miasma, p1_phase)
		
		if p1_miasma >= MAX_MIASMA and not p1_is_downed:
			_set_player_downed(1)
			
	elif player_id == 2:
		if p2_is_downed: return
		p2_miasma = clamp(p2_miasma + amount, 0.0, MAX_MIASMA)
		p2_phase = _calculate_phase(p2_miasma)
		miasma_changed.emit(2, p2_miasma, p2_phase)
		
		if p2_miasma >= MAX_MIASMA and not p2_is_downed:
			_set_player_downed(2)

# Reduzir Miasma
func reduce_miasma(player_id: int, amount: float) -> void:
	if player_id == 1:
		p1_miasma = clamp(p1_miasma - amount, 0.0, MAX_MIASMA)
		p1_phase = _calculate_phase(p1_miasma)
		miasma_changed.emit(1, p1_miasma, p1_phase)
	elif player_id == 2:
		p2_miasma = clamp(p2_miasma - amount, 0.0, MAX_MIASMA)
		p2_phase = _calculate_phase(p2_miasma)
		miasma_changed.emit(2, p2_miasma, p2_phase)

# Coletável: Frasco de Purificação (Adiciona ao Inventário)
func add_purification_vial() -> void:
	shared_vials_count += 1
	purification_vial_collected.emit(shared_vials_count)

# Consumir Frasco
func _process_vial_input() -> void:
	if shared_vials_count > 0:
		if Input.is_action_just_pressed("p1_use_vial") or Input.is_action_just_pressed("p2_use_vial"):
			consume_vial()

func consume_vial() -> void:
	if shared_vials_count <= 0: return
	shared_vials_count -= 1
	reduce_miasma(1, 30.0)
	reduce_miasma(2, 30.0)
	# Cura leve de HP
	p1_hp = clamp(p1_hp + 15.0, 0.0, MAX_HP)
	p2_hp = clamp(p2_hp + 15.0, 0.0, MAX_HP)
	hp_changed.emit(1, p1_hp)
	hp_changed.emit(2, p2_hp)
	purification_vial_used.emit(shared_vials_count)

# Cálculo de Fases
func _calculate_phase(miasma_val: float) -> MiasmaPhase:
	if miasma_val >= 100.0:
		return MiasmaPhase.PHASE_3_CRITICAL
	elif miasma_val >= 71.0:
		return MiasmaPhase.PHASE_2_MAX_POWER
	elif miasma_val >= 31.0:
		return MiasmaPhase.PHASE_1_MUTATION
	else:
		return MiasmaPhase.PHASE_0_NORMAL

# Efeitos de Sangramento/Necrose da Fase 2
func _process_phase_effects(delta: float) -> void:
	if p1_phase == MiasmaPhase.PHASE_2_MAX_POWER and not p1_is_downed:
		take_damage(1, NECROSIS_DAMAGE_PER_SEC * delta, 0.0)
		
	if p2_phase == MiasmaPhase.PHASE_2_MAX_POWER and not p2_is_downed:
		take_damage(2, NECROSIS_DAMAGE_PER_SEC * delta, 0.0)

# Mecânica de Transfusão de Miasma Entre Jogadores
func _process_transfusion_check(delta: float) -> void:
	if p1_node == null or p2_node == null: return
	
	var dist = p1_node.global_position.distance_to(p2_node.global_position)
	var p1_interact = Input.is_action_pressed("p1_interact")
	var p2_interact = Input.is_action_pressed("p2_interact")
	
	if dist <= TRANSFUSION_RADIUS and (p1_interact or p2_interact):
		# Identificar quem tem maior miasma (Giver) e menor miasma (Receiver)
		var giver_id: int = 0
		var receiver_id: int = 0
		
		if p1_miasma > p2_miasma + 5.0:
			giver_id = 1
			receiver_id = 2
		elif p2_miasma > p1_miasma + 5.0:
			giver_id = 2
			receiver_id = 1
			
		if giver_id != 0:
			var transfer_amount = TRANSFUSION_RATE_PER_SEC * delta
			reduce_miasma(giver_id, transfer_amount)
			add_miasma(receiver_id, transfer_amount * 0.7) # 30% dissipa no ar
			transfusion_active.emit(giver_id, receiver_id, transfer_amount)
			
			# Reanimação se estiver colapsado
			if giver_id == 1 and p1_is_downed and p1_miasma < 90.0:
				_revive_player(1)
			elif giver_id == 2 and p2_is_downed and p2_miasma < 90.0:
				_revive_player(2)

# Nocaute / Colapso
func _set_player_downed(player_id: int) -> void:
	if player_id == 1:
		p1_is_downed = true
		p1_hp = 0.0
	else:
		p2_is_downed = true
		p2_hp = 0.0
	player_downed.emit(player_id)

func _revive_player(player_id: int) -> void:
	if player_id == 1:
		p1_is_downed = false
		p1_hp = 25.0
		hp_changed.emit(1, p1_hp)
	else:
		p2_is_downed = false
		p2_hp = 25.0
		hp_changed.emit(2, p2_hp)
	player_revived.emit(player_id)

# Auxiliares de Multiplicadores de Dano/Velocidade baseados no Miasma
func get_damage_multiplier(player_id: int) -> float:
	var phase = p1_phase if player_id == 1 else p2_phase
	match phase:
		MiasmaPhase.PHASE_0_NORMAL: return 1.0
		MiasmaPhase.PHASE_1_MUTATION: return 1.25
		MiasmaPhase.PHASE_2_MAX_POWER: return 2.0 # Crítico 100%
		_: return 0.5

func get_speed_multiplier(player_id: int) -> float:
	var phase = p1_phase if player_id == 1 else p2_phase
	if phase == MiasmaPhase.PHASE_1_MUTATION or phase == MiasmaPhase.PHASE_2_MAX_POWER:
		return 1.3 if player_id == 2 else 1.15
	return 1.0
