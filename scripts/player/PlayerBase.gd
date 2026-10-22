class_name PlayerBase
extends CharacterBody2D

## PlayerBase.gd
## Classe Base Modular para os Personagens Jogáveis (Godot 4.x)
## Sanguis & Miasma: O Preço da Cura
##
## Integração completa com SpriteAnimator para fatiamento preciso de spritesheets por UV / Region Rect.

# ==============================================================================
# CONFIGURAÇÕES BÁSICAS DO JOGADOR
# ==============================================================================
@export var player_id: int = 1 # 1 = Baluarte, 2 = Ceifador
@export var base_speed: float = 160.0
@export var jump_velocity: float = -340.0
@export var gravity: float = 980.0

# ==============================================================================
# AJUSTE DE DIMENSÕES DA SPRITESHEET (EM PIXELS)
# ==============================================================================
## AJUSTE AQUI: Largura de cada frame do personagem na spritesheet (em pixels)
@export var sprite_frame_width: int = 128

## AJUSTE AQUI: Altura de cada frame do personagem na spritesheet (em pixels)
@export var sprite_frame_height: int = 128

# ==============================================================================
# REFERÊNCIAS A NÓS
# ==============================================================================
@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D

var animator: SpriteAnimator = null

# Estados internos
var is_attacking: bool = false
var invulnerable: bool = false
var i_frame_timer: float = 0.0

# Material do Shader de Brilho de Miasma
var miasma_shader_material: ShaderMaterial = null

func _ready() -> void:
	if player_id == 1:
		MiasmaManager.p1_node = self
	else:
		MiasmaManager.p2_node = self
		
	MiasmaManager.miasma_changed.connect(_on_miasma_changed)
	
	_setup_animator()
	_setup_shader()

## Inicializa e configura o SpriteAnimator com os dicionários de animação
func _setup_animator() -> void:
	# Busca o nó SpriteAnimator existente ou instancia proceduralmente
	if has_node("SpriteAnimator"):
		animator = $SpriteAnimator as SpriteAnimator
	else:
		animator = SpriteAnimator.new()
		animator.name = "SpriteAnimator"
		add_child(animator)
		
	# Dicionário Padrão de Animações do Jogador
	# ==============================================================================
	# AJUSTE AQUI: Mapeamento de linhas (row), colunas (col), frames e fps
	# da spritesheet dos personagens.
	# ==============================================================================
	var player_anims: Dictionary = {
		# Repouso (Linha 0, primeiros 4 quadros)
		"idle": {
			"row": 0,
			"col": 0,
			"frames": 4,
			"fps": 7.0,
			"loop": true,
			"frame_w": sprite_frame_width,
			"frame_h": sprite_frame_height
		},
		# Corrida / Caminhada (Linha 1, 4 quadros)
		"run": {
			"row": 1,
			"col": 0,
			"frames": 4,
			"fps": 10.0,
			"loop": true,
			"frame_w": sprite_frame_width,
			"frame_h": sprite_frame_height
		},
		# Salto no ar (Linha 1, coluna 4)
		"jump": {
			"row": 1,
			"col": 4,
			"frames": 1,
			"fps": 1.0,
			"loop": false,
			"frame_w": sprite_frame_width,
			"frame_h": sprite_frame_height
		},
		# Ataque primário (Linha 3, 4 quadros com rastro de golpe)
		"attack": {
			"row": 3,
			"col": 0,
			"frames": 4,
			"fps": 14.0,
			"loop": false,
			"frame_w": sprite_frame_width,
			"frame_h": sprite_frame_height
		},
		# Reação a Dano / Golpe sofrido (Linha 4, coluna 4)
		"hurt": {
			"row": 4,
			"col": 4,
			"frames": 2,
			"fps": 8.0,
			"loop": false,
			"frame_w": sprite_frame_width,
			"frame_h": sprite_frame_height
		}
	}
	
	animator.setup(sprite, player_anims, sprite_frame_width, sprite_frame_height)
	animator.play("idle")

func _setup_shader() -> void:
	var shader_file = load("res://shaders/player_miasma_glow.gdshader")
	if shader_file:
		miasma_shader_material = ShaderMaterial.new()
		miasma_shader_material.shader = shader_file
		if sprite:
			sprite.material = miasma_shader_material

func _physics_process(delta: float) -> void:
	# Checagem de Nocaute / Colapso
	var is_downed = MiasmaManager.p1_is_downed if player_id == 1 else MiasmaManager.p2_is_downed
	if is_downed:
		velocity.x = move_toward(velocity.x, 0, base_speed * delta * 4)
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		if animator:
			animator.play("hurt")
		return
		
	# Gravidade
	if not is_on_floor():
		velocity.y += gravity * delta
		
	# Processamento de i-frames (Invulnerabilidade pós-dano)
	if invulnerable:
		i_frame_timer -= delta
		if sprite:
			sprite.modulate.a = 0.5 if fmod(i_frame_timer, 0.1) > 0.05 else 1.0
		if i_frame_timer <= 0.0:
			invulnerable = false
			if sprite: sprite.modulate.a = 1.0
			
	# Movimento Horizontal
	var prefix = "p1_" if player_id == 1 else "p2_"
	var speed_mult = MiasmaManager.get_speed_multiplier(player_id)
	var current_speed = base_speed * speed_mult
	
	var input_dir = Input.get_axis(prefix + "left", prefix + "right")
	if input_dir != 0:
		velocity.x = input_dir * current_speed
		if sprite:
			sprite.flip_h = (input_dir < 0)
			if attack_area:
				attack_area.position.x = -abs(attack_area.position.x) if input_dir < 0 else abs(attack_area.position.x)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		
	# Pulo Base
	if Input.is_action_just_pressed(prefix + "jump") and is_on_floor():
		velocity.y = jump_velocity
		if AudioManager: AudioManager.play_jump_sfx()
		
	move_and_slide()
	_process_animation(delta)

## Máquina de Estados de Animação: seleciona a animação recortada correta
func _process_animation(_delta: float) -> void:
	if animator == null:
		return
		
	# Prioridade 1: Ataque em andamento
	if is_attacking:
		animator.play("attack")
		return
		
	# Prioridade 2: Hurt recente
	if invulnerable and i_frame_timer > 0.5:
		animator.play("hurt")
		return
		
	# Prioridade 3: No ar (Pulo / Queda)
	if not is_on_floor():
		animator.play("jump")
		return
		
	# Prioridade 4: Movimento horizontal
	if abs(velocity.x) > 10.0:
		animator.play("run")
	else:
		animator.play("idle")

# Atualização de parâmetros do Shader baseados no nível de Miasma
func _on_miasma_changed(pid: int, miasma_val: float, _phase: int) -> void:
	if pid == player_id and miasma_shader_material:
		var is_active = (miasma_val >= 70.0)
		miasma_shader_material.set_shader_parameter("is_active", is_active)

# Receber Dano com invulnerabilidade temporária
func apply_hit(damage: float, miasma_amount: float = 0.0) -> void:
	if invulnerable: return
	
	invulnerable = true
	i_frame_timer = 0.8
	if AudioManager: AudioManager.play_hit_sfx()
	MiasmaManager.take_damage(player_id, damage, miasma_amount)
	
	if animator:
		animator.play("hurt", true)

# Aplicar Ataque a Inimigos na Area2D
func perform_attack_deal_damage(damage: float, is_aoe: bool = false) -> void:
	if AudioManager: AudioManager.play_attack_sfx()
	if animator:
		animator.play("attack", true)
	
	if attack_area == null: return
	var bodies = attack_area.get_overlapping_bodies()
	var dmg_mult = MiasmaManager.get_damage_multiplier(player_id)
	var final_damage = damage * dmg_mult
	
	MiasmaManager.add_miasma(player_id, 1.5)
	
	for body in bodies:
		if body.has_method("take_enemy_damage"):
			var hit_dir = -1.0 if sprite and sprite.flip_h else 1.0
			body.take_enemy_damage(final_damage, player_id, hit_dir, is_aoe)
