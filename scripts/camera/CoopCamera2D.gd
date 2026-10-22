class_name CoopCamera2D
extends Camera2D

## CoopCamera2D.gd
## Câmera Dinâmica Cooperativa Multi-Alvo (Godot 4.x)
## Sanguis & Miasma: O Preço da Cura
##
## Centraliza suavemente no ponto médio de P1 e P2, calcula o zoom adaptativo
## para conter ambos com margem de segurança (padding) e aplica trava rígida
## contra os limites do cenário (world_bounds) para nunca exibir vãos pretos.

# ==============================================================================
# LIMITES DO MUNDO (WORLD BOUNDS)
# ==============================================================================
## Área retangular estrita do cenário navegável.
## A câmera e seu zoom nunca ultrapassarão estes limites.
@export var world_bounds: Rect2 = Rect2(-380, -180, 3960, 540)

# ==============================================================================
# CONFIGURAÇÃO DE ZOOM E MARGEM
# ==============================================================================
@export var min_zoom: float = 0.65
@export var max_zoom: float = 1.25

## Margem de respiro ao redor dos jogadores (em pixels)
@export var safe_padding: Vector2 = Vector2(120.0, 80.0)

## Distância máxima permitida entre os jogadores antes de aplicar a trava
@export var max_player_distance: float = 560.0

## Velocidades de suavização (interpolação linear / lerp)
@export var smooth_speed: float = 6.0
@export var zoom_smooth_speed: float = 4.5

var p1_ref: Node2D = null
var p2_ref: Node2D = null

func _ready() -> void:
	enabled = true
	make_current()
	position_smoothing_enabled = false # Usamos interpolação explícita no script para sincronia com zoom
	
	# Configura limites rígidos da própria Camera2D do Godot como salvaguarda
	limit_left = int(world_bounds.position.x)
	limit_top = int(world_bounds.position.y)
	limit_right = int(world_bounds.end.x)
	limit_bottom = int(world_bounds.end.y)
	limit_smoothed = true

func _process(delta: float) -> void:
	_resolve_player_references()
	
	if p1_ref == null and p2_ref == null:
		return
		
	var viewport_size = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(640, 360)
		
	var target_center: Vector2
	var target_zoom_factor: float
	
	# Caso 1: Ambos os jogadores ativos
	if p1_ref and p2_ref:
		# Ponto médio exato entre P1 e P2: (P1 + P2) / 2
		target_center = (p1_ref.global_position + p2_ref.global_position) * 0.5
		
		# Bounding Box dos jogadores incluindo margem de segurança (padding)
		var p1_pos = p1_ref.global_position
		var p2_pos = p2_ref.global_position
		var distance = p1_pos.distance_to(p2_pos)
		
		var required_width = abs(p1_pos.x - p2_pos.x) + safe_padding.x * 2.0
		var required_height = abs(p1_pos.y - p2_pos.y) + safe_padding.y * 2.0
		
		# Cálculo de zoom proporcional ao tamanho da tela
		var zoom_x = viewport_size.x / max(required_width, 1.0)
		var zoom_y = viewport_size.y / max(required_height, 1.0)
		var raw_zoom = min(zoom_x, zoom_y)
		
		# Clamp estrito de Zoom para que a área visível nunca ultrapasse world_bounds
		var limit_zoom_x = viewport_size.x / world_bounds.size.x
		var limit_zoom_y = viewport_size.y / world_bounds.size.y
		var absolute_min_zoom = max(limit_zoom_x, limit_zoom_y)
		var effective_min_zoom = max(min_zoom, absolute_min_zoom)
		
		target_zoom_factor = clamp(raw_zoom, effective_min_zoom, max_zoom)
		
		# Trava física: impede que jogadores ultrapassem a distância limite
		_clamp_player_distance(distance)
		
	# Caso 2: Apenas um jogador ativo (P1 ou P2)
	elif p1_ref:
		target_center = p1_ref.global_position
		target_zoom_factor = 1.0
	else:
		target_center = p2_ref.global_position
		target_zoom_factor = 1.0
		
	# Restringe jogadores dentro dos limites do mundo
	_clamp_players_to_bounds()
	
	# Interpolação suave do Zoom
	var next_zoom_val = lerp(zoom.x, target_zoom_factor, delta * zoom_smooth_speed)
	zoom = Vector2(next_zoom_val, next_zoom_val)
	
	# Confinamento rígido do centro da câmera dentro dos limites visíveis do mapa
	var clamped_target = clamp_to_bounds(target_center, zoom.x, viewport_size, world_bounds)
	
	# Interpolação suave de Posição
	global_position = global_position.lerp(clamped_target, delta * smooth_speed)

## Recupera referências dos jogadores caso ainda não tenham sido injetadas
func _resolve_player_references() -> void:
	if p1_ref == null or not is_instance_valid(p1_ref):
		p1_ref = MiasmaManager.p1_node
	if p2_ref == null or not is_instance_valid(p2_ref):
		p2_ref = MiasmaManager.p2_node

## Garante que o retângulo visível da câmera nunca ultrapasse a área do world_bounds
func clamp_to_bounds(target_pos: Vector2, current_zoom: float, v_size: Vector2, bounds: Rect2) -> Vector2:
	var half_view = (v_size / current_zoom) * 0.5
	
	var min_x = bounds.position.x + half_view.x
	var max_x = bounds.end.x - half_view.x
	var min_y = bounds.position.y + half_view.y
	var max_y = bounds.end.y - half_view.y
	
	var result_x = clamp(target_pos.x, min_x, max_x) if min_x <= max_x else bounds.get_center().x
	var result_y = clamp(target_pos.y, min_y, max_y) if min_y <= max_y else bounds.get_center().y
	
	return Vector2(result_x, result_y)

## Impede que os jogadores se afastem além da margem máxima de tethering
func _clamp_player_distance(current_distance: float) -> void:
	if current_distance > max_player_distance and p1_ref and p2_ref:
		var center = (p1_ref.global_position + p2_ref.global_position) * 0.5
		var p1_dir = (p1_ref.global_position - center).normalized()
		var p2_dir = (p2_ref.global_position - center).normalized()
		
		var half_max = max_player_distance * 0.5
		p1_ref.global_position = center + p1_dir * half_max
		p2_ref.global_position = center + p2_dir * half_max

## Conclui a contenção dos jogadores dentro dos limites do mapa
func _clamp_players_to_bounds() -> void:
	var margin: float = 24.0
	if p1_ref:
		p1_ref.global_position.x = clamp(p1_ref.global_position.x, world_bounds.position.x + margin, world_bounds.end.x - margin)
		p1_ref.global_position.y = clamp(p1_ref.global_position.y, world_bounds.position.y + margin, world_bounds.end.y - margin)
	if p2_ref:
		p2_ref.global_position.x = clamp(p2_ref.global_position.x, world_bounds.position.x + margin, world_bounds.end.x - margin)
		p2_ref.global_position.y = clamp(p2_ref.global_position.y, world_bounds.position.y + margin, world_bounds.end.y - margin)
