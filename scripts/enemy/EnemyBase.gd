class_name EnemyBase
extends CharacterBody2D

## EnemyBase.gd
## Classe Base com FSM (Finite State Machine) para Inimigos do Bestiário Alfa
## Sanguis & Miasma: O Preço da Cura (Godot 4.x)
##
## Integração modular com SpriteAnimator para corte e animação de spritesheets.

enum State { IDLE, PATROL, CHASE, ATTACK, STAGGER, DEAD }

@export var max_health: float = 50.0
@export var move_speed: float = 80.0
@export var attack_damage: float = 12.0
@export var miasma_on_hit: float = 8.0
@export var detection_radius: float = 200.0
@export var attack_radius: float = 32.0
@export var gravity: float = 980.0

# ==============================================================================
# AJUSTE DE DIMENSÕES DA SPRITESHEET DO INIMIGO (EM PIXELS)
# ==============================================================================
## AJUSTE AQUI: Largura de cada frame do inimigo (em pixels)
@export var enemy_frame_width: int = 48

## AJUSTE AQUI: Altura de cada frame do inimigo (em pixels)
@export var enemy_frame_height: int = 48

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea

var animator: SpriteAnimator = null
var current_health: float = 50.0
var current_state: State = State.IDLE
var target_player: CharacterBody2D = null

var hit_flash_timer: float = 0.0

func _ready() -> void:
	current_health = max_health
	_setup_animator()

## Inicializa o componente de animação e fatiamento UV
func _setup_animator() -> void:
	if has_node("SpriteAnimator"):
		animator = $SpriteAnimator as SpriteAnimator
	else:
		animator = SpriteAnimator.new()
		animator.name = "SpriteAnimator"
		add_child(animator)
		
	# ==============================================================================
	# AJUSTE AQUI: Mapa padrão de animações de inimigos
	# Subclasses podem registrar seus próprios dicionários ou sobrescrever este método.
	# ==============================================================================
	var default_enemy_anims: Dictionary = {
		"idle": {
			"row": 0,
			"col": 0,
			"frames": 2,
			"fps": 5.0,
			"loop": true,
			"frame_w": enemy_frame_width,
			"frame_h": enemy_frame_height
		},
		"run": {
			"row": 0,
			"col": 0,
			"frames": 4,
			"fps": 8.0,
			"loop": true,
			"frame_w": enemy_frame_width,
			"frame_h": enemy_frame_height
		},
		"attack": {
			"row": 0,
			"col": 2,
			"frames": 2,
			"fps": 10.0,
			"loop": false,
			"frame_w": enemy_frame_width,
			"frame_h": enemy_frame_height
		},
		"hurt": {
			"row": 0,
			"col": 0,
			"frames": 1,
			"fps": 1.0,
			"loop": false,
			"frame_w": enemy_frame_width,
			"frame_h": enemy_frame_height
		},
		"dead": {
			"row": 0,
			"col": 3,
			"frames": 1,
			"fps": 1.0,
			"loop": false,
			"frame_w": enemy_frame_width,
			"frame_h": enemy_frame_height
		}
	}
	
	animator.setup(sprite, default_enemy_anims, enemy_frame_width, enemy_frame_height)
	animator.play("idle")

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD: return
	
	if not is_on_floor():
		velocity.y += gravity * delta
		
	# Efeito de Flash Vermelho ao receber dano
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		if hit_flash_timer <= 0.0 and sprite:
			sprite.modulate = Color(1.0, 1.0, 1.0)
			
	# Atualizar Busca pelo Jogador Mais Próximo
	_update_target_player()
	
	# Executar FSM de acordo com a subclasse
	_state_logic(delta)
	
	move_and_slide()
	_update_animation()

## Atualiza a animação com base no estado da FSM
func _update_animation() -> void:
	if animator == null: return
	
	match current_state:
		State.IDLE:
			animator.play("idle")
		State.CHASE, State.PATROL:
			animator.play("run")
		State.ATTACK:
			animator.play("attack")
		State.STAGGER:
			animator.play("hurt")
		State.DEAD:
			animator.play("dead")

func _update_target_player() -> void:
	var p1 = MiasmaManager.p1_node
	var p2 = MiasmaManager.p2_node
	
	var candidates = []
	if p1 and not MiasmaManager.p1_is_downed: candidates.append(p1)
	if p2 and not MiasmaManager.p2_is_downed: candidates.append(p2)
	
	if candidates.size() == 0:
		target_player = null
		return
		
	var closest: CharacterBody2D = null
	var min_dist: float = INF
	
	for p in candidates:
		var dist = global_position.distance_to(p.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = p
			
	if min_dist <= detection_radius:
		target_player = closest
	else:
		target_player = null

# Sobrescrevível por subclasses de inimigos
func _state_logic(_delta: float) -> void:
	pass

# Receber Dano
func take_enemy_damage(amount: float, _attacker_id: int, _hit_dir: float, _is_aoe: bool = false) -> void:
	if current_state == State.DEAD: return
	
	current_health -= amount
	hit_flash_timer = 0.15
	if sprite: sprite.modulate = Color(1.0, 0.2, 0.2)
	
	if animator:
		animator.play("hurt", true)
	
	if current_health <= 0.0:
		_die()

func _die() -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO
	if sprite: sprite.modulate = Color(0.3, 0.3, 0.3, 0.6)
	if animator: animator.play("dead")
	
	# Desativar colisões pós-morte
	collision_layer = 0
	collision_mask = 0
	
	# Desvanecer e deletar
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

# Causa dano no jogador colidido
func deal_damage_to_player(player: Node2D) -> void:
	if player and player.has_method("apply_hit"):
		var pid = player.player_id if "player_id" in player else 1
		player.apply_hit(attack_damage, miasma_on_hit)
