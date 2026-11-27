class_name CastleGame
extends Node2D

const KNIGHT_SCENE: PackedScene = preload("res://entities/knight/knight.tscn")
const RAT_SCENE: PackedScene = preload("res://entities/rat/rat.tscn")
const BAT_SCENE: PackedScene = preload("res://entities/bat/bat.tscn")
const ORC_SCENE: PackedScene = preload("res://entities/orc/orc.tscn")
const CRATE_SCENE: PackedScene = preload("res://interactables/crate/crate.tscn")
const DOOR_SCENE: PackedScene = preload("res://interactables/door/door.tscn")
const TORCH_SCENE: PackedScene = preload("res://interactables/props/castle_torch.tscn")
const SWITCH_SCENE: PackedScene = preload("res://interactables/switch/castle_switch.tscn")
const GATE_SCENE: PackedScene = preload("res://interactables/gate/iron_gate.tscn")
const SHOP_SCENE: PackedScene = preload("res://interactables/shop/castle_shop.tscn")
const HEART_PICKUP_SCENE: PackedScene = preload("res://interactables/pickup/heart_pickup.tscn")
const PLATFORM_TEX: Texture2D = preload("res://assets/sprites/tiles/castle_platform.png")
const DUNGEON_TILES_TEX: Texture2D = preload("res://dungens/dark/dark_titles.png")

const PILLAR_TEX: Texture2D = preload("res://assets/sprites/props/ruined_pillar.png")
const WINDOW_TEX: Texture2D = preload("res://assets/sprites/props/gothic_window.png")
const BANNER_TEX: Texture2D = preload("res://assets/sprites/props/torn_banner.png")
const RUBBLE_TEX: Texture2D = preload("res://assets/sprites/props/rubble_sheet.png")
const CHAIN_TEX: Texture2D = preload("res://assets/sprites/props/hanging_chain.png")

const DMG_COSTS: Array[int] = [15, 28, 45]
const HP_COSTS: Array[int] = [18, 32, 48]
const SHIELD_COSTS: Array[int] = [15, 26, 40]
const HEAL_COST: int = 8

@onready var backdrop: ColorRect = $CastleBackdrop
@onready var background_tiles: TileMapLayer = $BackgroundTiles
@onready var solid_tiles: TileMapLayer = $SolidTiles
@onready var props_container: Node2D = $Props
@onready var platforms_container: Node2D = $Platforms
@onready var interactables_container: Node2D = $Interactables
@onready var enemies_container: Node2D = $Enemies
@onready var pickups_container: Node2D = $Pickups
@onready var player_holder: Node2D = $PlayerHolder
@onready var camera: Camera2D = $Camera2D
@onready var hud: GameHUD = $GameHUD

var levels: Array[Dictionary] = []
var current_level_index: int = 0
var current_stage_type: String = "intro"

# Persistent Player Run Stats & Economy
var player_hearts: int = 3
var max_player_hearts: int = 3
var sword_damage: int = 1
var max_shield: int = 2
var shield_recharge_time: float = 3.0
var coins: int = 0
var dmg_lv: int = 0
var hp_lv: int = 0
var shield_lv: int = 0
var shop_appeared_before: bool = false

var enemies_remaining: int = 0
var is_transitioning: bool = false
var current_player: Node = null
var current_door: CastleDoor = null
var room_gates: Array[IronGate] = []
var room_switches: Array[CastleSwitch] = []
var room_shop: CastleShop = null
var current_boss: Node = null
var active_horde_wave: int = 0
var active_horde_enemies: int = 0
var boss_defeated: bool = false


func _ready() -> void:
	get_tree().paused = false
	pickups_container.add_to_group("pickups_container")
	_setup_tilesets()
	levels = CastleLevelData.get_levels()
	if hud:
		hud.restart_level_requested.connect(_on_restart_level_requested)
		hud.restart_game_requested.connect(_on_restart_game_requested)
		hud.shop_buy_requested.connect(_on_shop_buy_requested)
		hud.shop_closed.connect(_on_shop_closed)
		hud.dialogue_finished.connect(_on_dialogue_finished)
	load_level(0)


func _setup_tilesets() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 0)

	var source := TileSetAtlasSource.new()
	source.texture = DUNGEON_TILES_TEX
	source.texture_region_size = Vector2i(16, 16)
	tileset.add_source(source, 0)

	var solid_coords: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(3, 0)]
	var poly := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for coord in solid_coords:
		source.create_tile(coord)
		var data := source.get_tile_data(coord, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, poly)

	var bg_coords: Array[Vector2i] = [Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, 1)]
	for coord in bg_coords:
		source.create_tile(coord)

	background_tiles.tile_set = tileset
	background_tiles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background_tiles.scale = Vector2(3, 3)

	solid_tiles.tile_set = tileset
	solid_tiles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	solid_tiles.scale = Vector2(3, 3)


func _clear_level() -> void:
	background_tiles.clear()
	solid_tiles.clear()
	current_player = null
	current_door = null
	current_boss = null
	room_gates.clear()
	room_switches.clear()
	room_shop = null
	enemies_remaining = 0
	active_horde_wave = 0
	active_horde_enemies = 0
	boss_defeated = false

	for container in [props_container, platforms_container, interactables_container, enemies_container, pickups_container, player_holder]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()


func load_level(index: int) -> void:
	_clear_level()
	current_level_index = clampi(index, 0, levels.size() - 1)
	var level_data: Dictionary = levels[current_level_index]
	current_stage_type = level_data.get("stage_type", "combat")
	var grid: Array = level_data["grid"]
	var room_cols: int = grid[0].length()
	var room_width: float = room_cols * CastleLevelData.TILE_SIZE

	if AudioManager:
		if current_stage_type == "boss":
			AudioManager.play_boss_music()
		else:
			AudioManager.play_ambient_music()

	if backdrop:
		backdrop.size = Vector2(room_width + 128.0, 848.0)

	background_tiles.modulate = level_data.get("bg_tint", Color.WHITE)
	if hud:
		hud.hide_boss_bar()

	var shop_chance: float = level_data.get("shop_chance", 0.0)
	var spawn_shop_here := false
	if shop_chance >= 1.0:
		spawn_shop_here = true
	elif shop_chance > 0.0:
		if current_level_index == 5 and not shop_appeared_before:
			spawn_shop_here = true
		else:
			spawn_shop_here = randf() <= shop_chance
	if spawn_shop_here:
		shop_appeared_before = true

	var spawn_pos := Vector2(120.0, 596.0)
	var pending_enemies: Array[Node] = []
	var gate_cols_done: Dictionary = {}

	for gy in range(grid.size()):
		var row_str: String = grid[gy]
		var gx := 0
		while gx < row_str.length():
			var ch := row_str[gx]
			# Weathered dark background brickwork with fallen-kingdom patches
			var bg_tile := Vector2i(2, 0)
			if (gx * 5 + gy * 3) % 7 == 0:
				bg_tile = Vector2i(2, 1)
			elif (gx * 11 + gy * 7) % 13 == 0:
				bg_tile = Vector2i(3, 1)
			background_tiles.set_cell(Vector2i(gx, gy), 0, bg_tile)

			var cell_center := Vector2(gx * 48.0 + 24.0, gy * 48.0 + 24.0)
			var surface_y := (gy + 1) * 48.0

			match ch:
				"#":
					var wall_tile := Vector2i(3, 0) if (gx * 7 + gy * 3) % 3 == 0 else Vector2i(0, 0)
					solid_tiles.set_cell(Vector2i(gx, gy), 0, wall_tile)
				"=":
					var trim_tile := Vector2i(3, 0) if (gx * 5 + gy) % 4 == 0 else Vector2i(1, 0)
					solid_tiles.set_cell(Vector2i(gx, gy), 0, trim_tile)
				"-":
					var run_len := 1
					while gx + run_len < row_str.length() and row_str[gx + run_len] == "-":
						background_tiles.set_cell(Vector2i(gx + run_len, gy), 0, Vector2i(2, 0))
						run_len += 1
					_spawn_platform(gx, gy, run_len)
					gx += run_len
					continue
				"T":
					var torch := TORCH_SCENE.instantiate()
					torch.position = cell_center
					props_container.add_child(torch)
				"V":
					_spawn_prop_sprite(WINDOW_TEX, cell_center + Vector2(0, 10), Vector2(3, 3), -3)
				"P":
					_spawn_prop_sprite(PILLAR_TEX, Vector2(cell_center.x, surface_y - 96.0), Vector2(3, 3), -2)
				"F":
					_spawn_prop_sprite(BANNER_TEX, cell_center + Vector2(0, 14), Vector2(3, 3), -2)
				"h":
					_spawn_prop_sprite(CHAIN_TEX, Vector2(cell_center.x, gy * 48.0 + 72.0), Vector2(3, 3), -2)
				"u":
					var rubble_idx := (gx + gy) % 3
					_spawn_prop_region(RUBBLE_TEX, Rect2(rubble_idx * 16, 0, 16, 16), Vector2(cell_center.x, surface_y - 24.0), Vector2(3, 3), -1)
				"K":
					spawn_pos = Vector2(cell_center.x, surface_y - 28.0)
				"D":
					var door := DOOR_SCENE.instantiate() as CastleDoor
					door.position = Vector2(cell_center.x, surface_y - 72.0)
					door.scale = Vector2(3, 3)
					door.door_entered.connect(_on_door_entered)
					interactables_container.add_child(door)
					current_door = door
				"C", "G", "$":
					var crate := CRATE_SCENE.instantiate() as DestructibleCrate
					crate.position = Vector2(cell_center.x, surface_y - 24.0)
					if ch == "$":
						crate.drop_mode = "coins"
						crate.coin_min = 2
						crate.coin_max = 4
					elif ch == "G":
						crate.drop_mode = "heart"
						crate.guaranteed_heart = true
					else:
						crate.drop_mode = "heart"
					crate.crate_broken.connect(_on_crate_broken)
					interactables_container.add_child(crate)
				"I":
					if not gate_cols_done.has(gx):
						gate_cols_done[gx] = true
						var floor_surface_y := 13.0 * 48.0
						var gate := GATE_SCENE.instantiate() as IronGate
						gate.position = Vector2(cell_center.x, floor_surface_y - 72.0)
						interactables_container.add_child(gate)
						room_gates.append(gate)
				"W":
					var sw := SWITCH_SCENE.instantiate() as CastleSwitch
					sw.position = cell_center
					sw.activated.connect(_on_switch_activated)
					interactables_container.add_child(sw)
					room_switches.append(sw)
				"S":
					if spawn_shop_here:
						var shop := SHOP_SCENE.instantiate() as CastleShop
						shop.position = Vector2(cell_center.x, surface_y - 48.0)
						shop.shop_interact_requested.connect(_on_shop_interact_requested)
						interactables_container.add_child(shop)
						room_shop = shop
				"R":
					var rat := RAT_SCENE.instantiate()
					rat.position = Vector2(cell_center.x, surface_y - 18.0)
					pending_enemies.append(rat)
				"M":
					var bat := BAT_SCENE.instantiate()
					bat.position = cell_center
					pending_enemies.append(bat)
				"O":
					var orc := ORC_SCENE.instantiate()
					orc.position = Vector2(cell_center.x, surface_y - 28.0)
					pending_enemies.append(orc)
				"B":
					var boss := ORC_SCENE.instantiate()
					boss.is_boss = true
					boss.position = Vector2(cell_center.x, surface_y - 36.0)
					boss.boss_hp_changed.connect(_on_boss_hp_changed)
					boss.boss_horde_requested.connect(_on_boss_horde_requested)
					boss.boss_defeated_signal.connect(_on_boss_defeated)
					pending_enemies.append(boss)
					current_boss = boss
					if hud:
						hud.setup_boss_bar("TIRANO CORROMPIDO", 32, 32)
			gx += 1

	var knight := KNIGHT_SCENE.instantiate()
	knight.position = spawn_pos
	knight.add_to_group("player")
	knight.max_hearts = max_player_hearts
	knight.current_hearts = player_hearts
	knight.sword_damage = sword_damage
	knight.max_shield = max_shield
	knight.current_shield = max_shield
	knight.shield_recharge_time = shield_recharge_time
	knight.health_changed.connect(_on_player_health_changed)
	knight.shield_changed.connect(_on_player_shield_changed)
	knight.sword_state_changed.connect(_on_player_sword_state_changed)
	knight.player_damaged.connect(_on_player_damaged)
	knight.player_died.connect(_on_player_died)
	knight.coin_collected.connect(_on_coin_collected)
	player_holder.add_child(knight)
	knight.apply_stats(player_hearts, max_player_hearts, sword_damage, max_shield, shield_recharge_time)
	current_player = knight

	for enemy in pending_enemies:
		_register_enemy(enemy)

	if camera:
		camera.limit_left = 0
		camera.limit_right = int(room_width)
		camera.limit_top = 0
		camera.limit_bottom = 720
		camera.global_position = spawn_pos
		camera.offset = Vector2.ZERO

	if current_door:
		if current_stage_type != "intro" and current_stage_type != "boss" and enemies_remaining == 0:
			current_door.open(true)

	if hud:
		hud.update_hearts(player_hearts, max_player_hearts)
		hud.update_shields(knight.current_shield, max_shield)
		hud.update_coins(coins)
		hud.update_sword_state(true)
		hud.set_level_info(
			level_data["index"],
			levels.size(),
			level_data["title"],
			level_data["subtitle"],
			level_data.get("hint", "")
		)
		hud.update_stage_objective(enemies_remaining, current_stage_type, current_door != null and current_door.is_open)

	# Trigger Boss-Player narrative dialogue on Stage 10 entry
	if current_stage_type == "boss" and hud:
		if current_player:
			current_player.set("can_control", false)
		var lines: Array[Dictionary] = [
			{
				"speaker": "TIRANO CORROMPIDO",
				"color": Color("#c084fc"),
				"text": "Mais um cavaleiro tolo caminha sobre as ruínas deste reino... O miasma já corrompeu estas muralhas!"
			},
			{
				"speaker": "CAVALEIRO",
				"color": Color("#ffd166"),
				"text": "Eu vou derrubar o seu reinado hoje e impedir que você corrompa o resto do meu povo!"
			},
			{
				"speaker": "TIRANO CORROMPIDO",
				"color": Color("#c084fc"),
				"text": "Palavras ousadas! Sobreviva ao meu machado e às minhas hordas — se for capaz!"
			},
		]
		hud.start_dialogue(lines)


func _on_dialogue_finished() -> void:
	if current_player and not bool(current_player.get("is_dead")):
		current_player.set("can_control", true)
	if is_instance_valid(current_boss) and current_boss.has_method("start_boss_combat"):
		current_boss.start_boss_combat()


func _spawn_prop_sprite(tex: Texture2D, pos: Vector2, scl: Vector2, z_ord: int) -> void:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.position = pos
	sp.scale = scl
	sp.z_index = z_ord
	props_container.add_child(sp)


func _spawn_prop_region(tex: Texture2D, region: Rect2, pos: Vector2, scl: Vector2, z_ord: int) -> void:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.region_enabled = true
	sp.region_rect = region
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.position = pos
	sp.scale = scl
	sp.z_index = z_ord
	props_container.add_child(sp)


func _process(_delta: float) -> void:
	if camera and is_instance_valid(current_player):
		camera.global_position = current_player.global_position


func _spawn_platform(start_gx: int, gy: int, tile_count: int) -> void:
	var total_w := tile_count * 48.0
	var center_x := start_gx * 48.0 + total_w * 0.5
	var top_y := gy * 48.0

	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector2(center_x, top_y + 8.0)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(total_w, 16.0)
	shape.shape = rect
	shape.one_way_collision = true
	shape.one_way_collision_margin = 8.0
	body.add_child(shape)

	for i in range(tile_count):
		var seg := Sprite2D.new()
		seg.texture = PLATFORM_TEX
		seg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		seg.position = Vector2(-total_w * 0.5 + 24.0 + i * 48.0, 16.0)
		seg.scale = Vector2(1.0, 3.0)
		body.add_child(seg)

	platforms_container.add_child(body)


func _register_enemy(enemy: Node, is_horde_minion: bool = false) -> void:
	enemies_container.add_child(enemy)
	if is_horde_minion and enemy.has_method("set_boss_minion"):
		enemy.set_boss_minion(true)
	if enemy is Ai and current_player is Character:
		(enemy as Ai).track(current_player as Character)
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died.bind(is_horde_minion))
	enemies_remaining += 1


func _on_crate_broken(_crate: Node2D, _dropped_heart: bool) -> void:
	if current_stage_type == "intro" and current_door and not current_door.is_open:
		current_door.open(false)
		if hud:
			hud.update_stage_objective(enemies_remaining, current_stage_type, true)


func _on_switch_activated(_sw: Node2D) -> void:
	for gate in room_gates:
		if is_instance_valid(gate):
			gate.open_gate()
	if current_stage_type == "intro_throw" and hud:
		hud.update_stage_objective(enemies_remaining, current_stage_type, true)


func _on_enemy_died(_enemy: Node, is_horde_minion: bool = false) -> void:
	enemies_remaining = maxi(0, enemies_remaining - 1)
	if is_horde_minion and active_horde_enemies > 0:
		active_horde_enemies -= 1
		if active_horde_enemies == 0:
			_on_horde_wave_cleared()
	elif current_stage_type != "boss" and enemies_remaining == 0 and current_door:
		current_door.open(false)

	if hud:
		hud.update_stage_objective(enemies_remaining, current_stage_type, current_door != null and current_door.is_open, active_horde_wave)


func _on_boss_hp_changed(hp: int, max_hp: int) -> void:
	if hud:
		hud.update_boss_bar(hp, max_hp)


func _on_boss_horde_requested(wave: int) -> void:
	active_horde_wave = wave
	call_deferred("_spawn_horde_wave", wave)


func _spawn_horde_wave(wave: int) -> void:
	if not is_inside_tree():
		return
	active_horde_enemies = 0
	var callout_title := ""
	var callout_sub := ""

	match wave:
		1:
			callout_title = "HORDA I: RATOS DA PESTE!"
			callout_sub = "O Tirano recuou — derrote os 4 servos para trazê-lo de volta!"
			for x_pos in [220.0, 460.0, 920.0, 1140.0]:
				var rat := RAT_SCENE.instantiate()
				rat.position = Vector2(x_pos, 606.0)
				_register_enemy(rat, true)
				active_horde_enemies += 1
		2:
			callout_title = "HORDA II: MORCEGOS DO MIASMA!"
			callout_sub = "Use o escudo contra o guspe roxo dos 3 morcegos!"
			for pos in [Vector2(300.0, 210.0), Vector2(680.0, 190.0), Vector2(1060.0, 210.0)]:
				var bat := BAT_SCENE.instantiate()
				bat.position = pos
				_register_enemy(bat, true)
				active_horde_enemies += 1
		3:
			callout_title = "HORDA III: GUARDA CORROMPIDA!"
			callout_sub = "Penúltimo desafio — derrote os 2 Ogros para o duelo final!"
			for x_pos in [320.0, 1040.0]:
				var orc := ORC_SCENE.instantiate()
				orc.position = Vector2(x_pos, 596.0)
				_register_enemy(orc, true)
				active_horde_enemies += 1

	if hud:
		hud.show_boss_callout(callout_title, callout_sub, Color("#c084fc"))
		if is_instance_valid(current_boss):
			hud.update_boss_bar(current_boss.hp, current_boss.max_hp, "HORDA %d/3 — DERROTE OS SERVOS!" % wave)
		hud.update_stage_objective(enemies_remaining, current_stage_type, false, active_horde_wave)


func _on_horde_wave_cleared() -> void:
	var cleared := active_horde_wave
	active_horde_wave = 0
	# Mercy heart drop if player is at <= 50% HP after clearing a horde
	if player_hearts * 2 <= max_player_hearts:
		var heart := HEART_PICKUP_SCENE.instantiate()
		heart.global_position = Vector2(720.0, 560.0)
		pickups_container.call_deferred("add_child", heart)

	if is_instance_valid(current_boss) and current_boss.has_method("return_from_retreat"):
		current_boss.return_from_retreat(cleared)
		if hud:
			hud.update_boss_bar(current_boss.hp, current_boss.max_hp)
			var msg := "O duelo final começou!" if cleared >= 3 else "O Tirano voltou para a arena!"
			hud.show_boss_callout("TIRANO CORROMPIDO", msg, Color("#ff6b81"))


func _on_boss_defeated() -> void:
	boss_defeated = true
	if current_door:
		current_door.open(false)
	if hud:
		hud.hide_boss_bar()
		hud.show_boss_callout("REINADO DERRUBADO!", "Você purificou o castelo — avance pela porta!", Color("#ffd166"))
		hud.update_stage_objective(0, current_stage_type, true)


func _on_coin_collected(amount: int) -> void:
	coins += amount
	if hud:
		hud.update_coins(coins)


func _on_shop_interact_requested() -> void:
	if not hud or hud.is_shop_open or hud.is_overlay_active or hud.is_dialogue_open:
		return
	if current_player:
		current_player.set("can_control", false)
	hud.open_shop(coins, dmg_lv, hp_lv, shield_lv, player_hearts, max_player_hearts, DMG_COSTS, HP_COSTS, SHIELD_COSTS, HEAL_COST)


func _on_shop_closed() -> void:
	if current_player and not bool(current_player.get("is_dead")):
		current_player.set("can_control", true)


func _on_shop_buy_requested(item_id: String) -> void:
	var bought := false
	match item_id:
		"damage":
			if dmg_lv < DMG_COSTS.size() and coins >= DMG_COSTS[dmg_lv]:
				coins -= DMG_COSTS[dmg_lv]
				dmg_lv += 1
				sword_damage += 1
				bought = true
		"health":
			if hp_lv < HP_COSTS.size() and coins >= HP_COSTS[hp_lv]:
				coins -= HP_COSTS[hp_lv]
				hp_lv += 1
				max_player_hearts += 1
				player_hearts += 1
				bought = true
		"shield":
			if shield_lv < SHIELD_COSTS.size() and coins >= SHIELD_COSTS[shield_lv]:
				coins -= SHIELD_COSTS[shield_lv]
				shield_lv += 1
				max_shield += 1
				shield_recharge_time = maxf(1.8, shield_recharge_time - 0.35)
				bought = true
		"heal":
			if player_hearts < max_player_hearts and coins >= HEAL_COST:
				coins -= HEAL_COST
				player_hearts += 1
				bought = true

	if bought:
		if AudioManager:
			AudioManager.play_shop_buy_sfx()
		if current_player and current_player.has_method("apply_stats"):
			current_player.apply_stats(player_hearts, max_player_hearts, sword_damage, max_shield, shield_recharge_time)
			current_player.set("current_shield", max_shield)
			current_player.shield_changed.emit(max_shield, max_shield)
	else:
		if AudioManager:
			AudioManager.play_shop_deny_sfx()

	if hud:
		hud.refresh_shop(coins, dmg_lv, hp_lv, shield_lv, player_hearts, max_player_hearts, DMG_COSTS, HP_COSTS, SHIELD_COSTS, HEAL_COST)


func _on_player_health_changed(current_hearts: int, max_hearts: int) -> void:
	player_hearts = current_hearts
	max_player_hearts = max_hearts
	if hud:
		hud.update_hearts(current_hearts, max_hearts)


func _on_player_shield_changed(current_sh: int, max_sh: int) -> void:
	if hud:
		hud.update_shields(current_sh, max_sh)


func _on_player_sword_state_changed(has_sword: bool) -> void:
	if hud:
		hud.update_sword_state(has_sword)


func _on_player_damaged(_current_hearts: int) -> void:
	_shake_camera(7.0, 0.16)


func _shake_camera(intensity: float, duration: float) -> void:
	if not camera:
		return
	var tw := camera.create_tween()
	tw.tween_property(camera, "offset", Vector2(-intensity, intensity * 0.5), duration * 0.25)
	tw.tween_property(camera, "offset", Vector2(intensity, -intensity * 0.5), duration * 0.25)
	tw.tween_property(camera, "offset", Vector2(-intensity * 0.5, 0.0), duration * 0.25)
	tw.tween_property(camera, "offset", Vector2.ZERO, duration * 0.25)


func _on_player_died() -> void:
	if hud:
		hud.show_game_over()


func _on_door_entered() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	if current_player:
		current_player.set("can_control", false)

	if current_level_index + 1 >= levels.size():
		if hud:
			hud.show_victory(player_hearts, max_player_hearts, coins)
		is_transitioning = false
		return

	if hud:
		await hud.fade_to(1.0, 0.25)
	load_level(current_level_index + 1)
	if hud:
		await hud.fade_to(0.0, 0.25)
	is_transitioning = false


func _on_restart_level_requested() -> void:
	player_hearts = max_player_hearts
	load_level(current_level_index)


func _on_restart_game_requested() -> void:
	is_transitioning = false
	get_tree().paused = false
	if hud and hud.fade_rect:
		hud.fade_rect.color.a = 0.0
	max_player_hearts = 3
	player_hearts = 3
	sword_damage = 1
	max_shield = 2
	shield_recharge_time = 3.0
	coins = 0
	dmg_lv = 0
	hp_lv = 0
	shield_lv = 0
	shop_appeared_before = false
	load_level(0)
