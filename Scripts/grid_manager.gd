#
# File: Scripts/grid_manager.gd
#
class_name GridManager
extends Node2D

# --- EXPORTS & CONFIGURATION ---
@export var cell_size := Vector2i(64, 64)
@export var grid_dimensions := Vector2i(20, 15)
@export var grid_color := Color(0.5, 0.5, 0.5, 0.3)
@export var tile_scene: PackedScene


# --- SIGNALS ---
signal tile_placed(pos: Vector2i, tile_data: Tile_Data)
signal tile_removed(pos: Vector2i)
signal generation_recalculated(total_generation: Dictionary, per_tile_generation: Dictionary)
# --- NEW: A definitive signal that the game is over due to blight. ---
signal all_tiles_blighted


# --- PROPERTIES ---
var grid: Dictionary = {}
var neighbor_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
var core_pos: Vector2i


# --- GODOT ENGINE FUNCTIONS ---
func _ready() -> void:
	var blight_manager = get_node_or_null("../BlightManager")
	if blight_manager:
		blight_manager.tile_blighted.connect(set_tile_disabled.bind(true))
	else:
		push_warning("GridManager could not find BlightManager. Blight will not function.")

	call_deferred("_place_initial_core")

func _draw() -> void:
	var grid_width_pixels = grid_dimensions.x * cell_size.x
	var grid_height_pixels = grid_dimensions.y * cell_size.y

	for i in range(grid_dimensions.x + 1):
		var x = i * cell_size.x
		draw_line(Vector2(x, 0), Vector2(x, grid_height_pixels), grid_color, 1.0)

	for i in range(grid_dimensions.y + 1):
		var y = i * cell_size.y
		draw_line(Vector2(0, y), Vector2(grid_width_pixels, y), grid_color, 1.0)


# --- PUBLIC FUNCTIONS ---
func place_tile(pos: Vector2i, tile_data: Tile_Data) -> bool:
	if grid.has(pos) or not Rect2i(Vector2i.ZERO, grid_dimensions).has_point(pos):
		printerr("GridManager: Attempted to place tile on occupied or out-of-bounds cell %s" % str(pos))
		return false
	
	grid[pos] = {
		"tile_data": tile_data, "last_generation": {}, "cached_synergy": {},
		"disabled": false, "node_instance": null 
	}
	
	if tile_scene:
		var tile_instance: Tile = tile_scene.instantiate()
		add_child(tile_instance)
		tile_instance.position = (pos * cell_size) + (cell_size / 2)
		tile_instance.initialize(pos, tile_data)
		
		tile_instance.tile_clicked.connect(_on_any_tile_clicked)
		
		grid[pos].node_instance = tile_instance
	else:
		push_warning("GridManager: tile_scene is not set! Cannot create visual tile.")
	
	tile_placed.emit(pos, tile_data)
	
	_recalculate_generation()
	for dir in neighbor_dirs:
		if grid.has(pos + dir):
			_recalculate_generation()
			break
	return true


func world_to_grid_coords(world_pos: Vector2) -> Vector2i:
	var local_pos = to_local(world_pos)
	return Vector2i(floor(local_pos.x / cell_size.x), floor(local_pos.y / cell_size.y))


func set_tile_disabled(pos: Vector2i, is_disabled: bool) -> void:
	if not grid.has(pos):
		return

	var tile_instance_data = grid[pos]
	if tile_instance_data.disabled == is_disabled:
		return

	tile_instance_data.disabled = is_disabled
	print("GridManager: Tile at %s has been %s." % [pos, "disabled" if is_disabled else "enabled"])

	if tile_instance_data.node_instance:
		var tile_node: Node2D = tile_instance_data.node_instance
		tile_node.modulate = Color.DARK_GRAY if is_disabled else Color.WHITE

	_recalculate_generation()
	
	# --- CHANGE: Check for game over condition AFTER disabling the tile. ---
	_check_for_blight_game_over()


func attempt_upgrade_core(pos: Vector2i) -> void:
	if not grid.has(pos) or not grid[pos].tile_data.tags.has(&"core_tile"):
		return

	var tile_instance = grid[pos]
	var td: Tile_Data = tile_instance.tile_data
	var current_level = td.metadata.get("upgrade_level", 0)
	var upgrade_path: Array = td.metadata.get("upgrade_path", [])

	if current_level >= upgrade_path.size():
		print("Core is already max level.")
		return

	var next_upgrade = upgrade_path[current_level]
	var upgrade_cost = next_upgrade.get("cost", {})

	if ResourceManager.spend_resources(upgrade_cost):
		print("Upgrading Core to level %d" % (current_level + 1))
		td.metadata["upgrade_level"] = current_level + 1
		
		var bonus = next_upgrade.get("generation_bonus", {})
		for resource_key in bonus:
			td.base_generation[resource_key] = td.base_generation.get(resource_key, 0.0) + bonus[resource_key]
		
		_recalculate_generation()
	else:
		print("Cannot afford Core upgrade.")


# --- PRIVATE LOGIC ---
func _recalculate_generation() -> void:
	var total_generation := {}
	var per_tile_generation := {}
	for pos in grid.keys():
		var inst = grid[pos]
		var tile_gen: Dictionary = _compute_tile_generation(pos, inst)
		inst.last_generation = tile_gen
		per_tile_generation[pos] = tile_gen
		for resource_key in tile_gen:
			total_generation[resource_key] = total_generation.get(resource_key, 0.0) + tile_gen[resource_key]
	generation_recalculated.emit(total_generation, per_tile_generation)

func _compute_tile_generation(pos: Vector2i, inst: Dictionary) -> Dictionary:
	if inst.disabled: return {}
	var td: Tile_Data = inst.tile_data
	var output: Dictionary = td.base_generation.duplicate()

	var total_shield_strength: float = 0.0
	var is_adjacent_to_blight: bool = false
	
	for dir in neighbor_dirs:
		var neighbor_pos = pos + dir
		if not grid.has(neighbor_pos): continue
		
		var neighbor_inst = grid[neighbor_pos]
		
		if neighbor_inst.disabled:
			is_adjacent_to_blight = true
		
		if not neighbor_inst.disabled:
			var neighbor_td: Tile_Data = neighbor_inst.tile_data
			for tag in neighbor_td.tags:
				if tag.begins_with("shield_strength:"):
					var strength_str = tag.split(":")[1]
					if strength_str.is_valid_float():
						total_shield_strength += strength_str.to_float()

	for dir in neighbor_dirs:
		var neighbor_pos := pos + dir
		if not grid.has(neighbor_pos): continue
		var neighbor_inst = grid[neighbor_pos]
		if neighbor_inst.disabled: continue
		var neighbor_td: Tile_Data = neighbor_inst.tile_data
		if td.synergy_rules.has(neighbor_td.category):
			var rule: Dictionary = td.synergy_rules[neighbor_td.category]
			_apply_synergy_rule(output, rule, neighbor_td, total_shield_strength)
	
	if is_adjacent_to_blight:
		var blight_penalty_rule: Dictionary = {
			"type": "penalty",
			"factor": 0.5 
		}
		_apply_synergy_rule(output, blight_penalty_rule, null, total_shield_strength)

	return output

func _place_initial_core() -> void:
	var core_data: Tile_Data = ResourceCatalog.tiles.get(&"core")
	if not core_data:
		push_error("GridManager: Could not find 'core' TileData in ResourceCatalog!")
		return
	
	core_pos = grid_dimensions / 2
	place_tile(core_pos, core_data)
	
func _apply_synergy_rule(output: Dictionary, rule: Dictionary, neighbor_data: Tile_Data, shield_strength: float = 0.0) -> void:
	match rule.get("type", ""):
		"additive":
			var res: StringName = rule.get("resource", &"")
			if res != &"": output[res] = output.get(res, 0.0) + rule.get("value", 0.0)
		"multiplier":
			var target: StringName = rule.get("target", &"")
			if target != &"" and output.has(target): output[target] *= rule.get("factor", 1.0)
		"penalty":
			var factor = rule.get("factor", 1.0)
			if shield_strength > 0.0:
				var penalty_amount = 1.0 - factor
				var effective_penalty = penalty_amount * (1.0 - clampf(shield_strength, 0.0, 1.0))
				factor = 1.0 - effective_penalty
			
			for key in output: output[key] *= factor
		_:
			pass

func _on_any_tile_clicked(pos: Vector2i) -> void:
	if grid.has(pos) and grid[pos].tile_data.tags.has(&"core_tile"):
		attempt_upgrade_core(pos)


# --- NEW: This function now lives in the GridManager, the source of truth. ---
func _check_for_blight_game_over() -> void:
	# Iterate through all tiles.
	for pos in grid:
		var tile = grid[pos]
		# If we find any tile that is NOT the Core and is NOT disabled...
		if not tile.tile_data.tags.has(&"core_tile") and not tile.disabled:
			# ...then the game is not over yet. We can stop checking.
			return
	
	# If the loop completes, it means no active, non-Core tiles were found.
	# We must also check that there is more than just the Core tile on the board.
	# Otherwise, the game would end immediately when only the Core exists.
	if grid.size() > 1:
		all_tiles_blighted.emit()
