class_name SpriteAnimator
extends Node

## SpriteAnimator.gd
## Módulo Reutilizável de Fatiamento e Animação de Spritesheets (Godot 4.x)
## Sanguis & Miasma: O Preço da Cura
##
## Corta a textura da spritesheet em coordenadas retangulares / UV (Region Rect)
## garantindo que APENAS o frame ativo seja desenhado, sem renderizar a folha inteira.

# ==============================================================================
# CONFIGURAÇÃO DE ALVO E DIMENSÕES DE FRAME (AJUSTE AQUI)
# ==============================================================================
## O nó Sprite2D onde a spritesheet está aplicada.
@export var target_sprite: Sprite2D = null

## AJUSTE AQUI: Largura padrão de cada frame (em pixels)
@export var default_frame_width: int = 64

## AJUSTE AQUI: Altura padrão de cada frame (em pixels)
@export var default_frame_height: int = 64

## Se verdadeiro, o SpriteAnimator atualiza automaticamente no loop de _process
@export var auto_process: bool = true

# ==============================================================================
# MAPA DE ANIMAÇÕES
# ==============================================================================
## Dicionário contendo as configurações de cada estado de animação.
## Formato suportado por grade (row/col) ou coordenadas retangulares diretas:
## {
##   "idle": {
##       "row": 0,             # Linha na folha (0-indexed)
##       "col": 0,             # Coluna inicial (0-indexed)
##       "frames": 4,          # Quantidade de quadros
##       "fps": 8.0,           # Velocidade (taxa de atualização por segundo)
##       "loop": true,         # Repetição cíclica
##       "frame_w": 64,        # Opcional: sobrescreve default_frame_width
##       "frame_h": 64         # Opcional: sobrescreve default_frame_height
##   },
##   "attack": {
##       "frame_x": 0,         # Coordenada X inicial em pixels
##       "frame_y": 128,       # Coordenada Y inicial em pixels
##       "frame_width": 64,    # Largura do frame em pixels
##       "frame_height": 64,   # Altura do frame em pixels
##       "frames": 4,
##       "fps": 12.0,
##       "loop": false
##   }
## }
var animations: Dictionary = {}

# ==============================================================================
# VARIÁVEIS DE CONTROLE INTERNO
# ==============================================================================
var current_anim: String = ""
var current_frame_idx: int = 0
var anim_timer: float = 0.0
var is_playing: bool = false
var is_finished: bool = false

# Sinais de controle
signal animation_finished(anim_name: String)
signal frame_changed(anim_name: String, frame_idx: int)

func _ready() -> void:
	if target_sprite == null:
		if get_parent() is Sprite2D:
			target_sprite = get_parent() as Sprite2D
		elif get_parent() and get_parent().has_node("Sprite2D"):
			target_sprite = get_parent().get_node("Sprite2D") as Sprite2D
			
	if target_sprite:
		_prepare_sprite()

## Configura e ativa o Sprite2D e o mapa de animações
func setup(sprite_node: Sprite2D, anim_dict: Dictionary, frame_w: int = 64, frame_h: int = 64) -> void:
	target_sprite = sprite_node
	animations = anim_dict
	default_frame_width = frame_w
	default_frame_height = frame_h
	_prepare_sprite()

## Adiciona ou substitui uma animação dinamicamente no dicionário
func add_animation(anim_name: String, anim_data: Dictionary) -> void:
	animations[anim_name] = anim_data

## Inicia a reprodução de um estado de animação
func play(anim_name: String, force_restart: bool = false) -> void:
	if not animations.has(anim_name):
		# Se não encontrar a animação requisitada, tenta recorrer para 'idle' se existir
		if anim_name != "idle" and animations.has("idle"):
			anim_name = "idle"
		else:
			return
		
	if current_anim == anim_name and is_playing and not force_restart:
		return
		
	current_anim = anim_name
	current_frame_idx = 0
	anim_timer = 0.0
	is_playing = true
	is_finished = false
	
	_apply_frame_rect()
	frame_changed.emit(current_anim, current_frame_idx)

## Pausa a reprodução mantendo o quadro atual
func pause() -> void:
	is_playing = false

## Retoma a reprodução da animação
func resume() -> void:
	if current_anim != "" and not is_finished:
		is_playing = true

## Interrompe a animação e reseta o quadro
func stop() -> void:
	is_playing = false
	current_frame_idx = 0
	_apply_frame_rect()

## Retorna o nome da animação atual em execução
func get_current_animation() -> String:
	return current_anim

## Retorna se a animação não-cíclica atual já completou
func is_current_finished() -> bool:
	return is_finished

func _process(delta: float) -> void:
	if auto_process:
		update(delta)

## Processa o avanço temporal e a troca de quadros por delta
func update(delta: float) -> void:
	if not is_playing or not animations.has(current_anim):
		return
		
	var data: Dictionary = animations[current_anim]
	var fps: float = data.get("fps", data.get("animation_speed", 8.0))
	var total_frames: int = data.get("frames", 1)
	var loop: bool = data.get("loop", true)
	
	if fps <= 0.0:
		return
		
	anim_timer += delta
	var frame_duration: float = 1.0 / fps
	
	if anim_timer >= frame_duration:
		anim_timer -= frame_duration
		current_frame_idx += 1
		
		if current_frame_idx >= total_frames:
			if loop:
				current_frame_idx = 0
			else:
				current_frame_idx = total_frames - 1
				is_playing = false
				is_finished = true
				_apply_frame_rect()
				animation_finished.emit(current_anim)
				return
				
		_apply_frame_rect()
		frame_changed.emit(current_anim, current_frame_idx)

## Garante que o Sprite2D utilize modo de recorte por Região e não subdivisões conflitantes
func _prepare_sprite() -> void:
	if target_sprite == null:
		return
	# Ativa o modo de recorte retangular (UV coordinates / Region Rect)
	target_sprite.region_enabled = true
	# Evita que o Godot subdivida a região já recortada
	target_sprite.hframes = 1
	target_sprite.vframes = 1

## Fatiamento: Calcula e aplica o Rect2 exato do frame ativo na spritesheet
func _apply_frame_rect() -> void:
	if target_sprite == null or not animations.has(current_anim):
		return
		
	var data: Dictionary = animations[current_anim]
	
	# Determina largura e altura do frame (específica da animação ou padrão global)
	var fw: int = data.get("frame_w", data.get("frame_width", default_frame_width))
	var fh: int = data.get("frame_h", data.get("frame_height", default_frame_height))
	
	var rect_x: float = 0.0
	var rect_y: float = 0.0
	
	# Caso 1: Coordenadas em pixels especificadas diretamente
	if data.has("frame_x") or data.has("frame_y"):
		var base_x: float = data.get("frame_x", 0.0)
		var base_y: float = data.get("frame_y", 0.0)
		rect_x = base_x + (current_frame_idx * fw)
		rect_y = base_y
	# Caso 2: Linha (row) e Coluna (col) na grade da folha
	else:
		var row: int = data.get("row", 0)
		var start_col: int = data.get("col", 0)
		rect_x = (start_col + current_frame_idx) * fw
		rect_y = row * fh
	
	# Aplica o recorte exato do frame ativo
	target_sprite.region_enabled = true
	target_sprite.region_rect = Rect2(rect_x, rect_y, fw, fh)
