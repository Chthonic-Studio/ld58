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


# --- PROPERTIES ---
var grid: Dictionary = {}
var neighbor_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


# --- GODOT ENGINE FUNCTIONS ---
func _ready() -> void:
	var blight_manager = get_node_or_null("../BlightManager")
	if blight_manager:
		blight_manager.tile_blighted.connect(set_tile_disabled.bind(true))
	else:
		push_warning("GridManager could not find BlightManager. Blight will not function.")


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
		grid[pos].node_instance = tile_instance
	else:
		push_warning("GridManager: tile_scene is not set! Cannot create visual tile.")
	
	# The GridManager's only job is to announce what was placed and where.
	tile_placed.emit(pos, tile_data)
	
	_recalculate_generation()
	# When placing a tile, we must also recalculate neighbors since their synergies might change.
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


# --- PRIVATE LOGIC ---
# ... (The rest of the private functions are unchanged and correct)
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

	# --- CHANGE: Calculate shield strength from neighbors FIRST ---
	var total_shield_strength: float = 0.0
	for dir in neighbor_dirs:
		var neighbor_pos = pos + dir
		if not grid.has(neighbor_pos): continue
		
		var neighbor_inst = grid[neighbor_pos]
		if neighbor_inst.disabled: continue
		
		var neighbor_td: Tile_Data = neighbor_inst.tile_data
		for tag in neighbor_td.tags:
			if tag.begins_with("shield_strength:"):
				var strength_str = tag.split(":")[1]
				if strength_str.is_valid_float():
					total_shield_strength += strength_str.to_float()

	# Apply synergy rules from neighbors
	for dir in neighbor_dirs:
		var neighbor_pos := pos + dir
		if not grid.has(neighbor_pos): continue
		var neighbor_inst = grid[neighbor_pos]
		if neighbor_inst.disabled: continue
		var neighbor_td: Tile_Data = neighbor_inst.tile_data
		if td.synergy_rules.has(neighbor_td.category):
			var rule: Dictionary = td.synergy_rules[neighbor_td.category]
			# --- CHANGE: Pass the calculated shield strength to the rule application ---
			_apply_synergy_rule(output, rule, neighbor_td, total_shield_strength)
	return output

func _apply_synergy_rule(output: Dictionary, rule: Dictionary, neighbor_data: Tile_Data, shield_strength: float = 0.0) -> void:
	match rule.get("type", ""):
		"additive":
			var res: StringName = rule.get("resource", &"")
			if res != &"": output[res] = output.get(res, 0.0) + rule.get("value", 0.0)
		"multiplier":
			var target: StringName = rule.get("target", &"")
			if target != &"" and output.has(target): output[target] *= rule.get("factor", 1.0)
		"penalty":
			# --- CHANGE: Shield Node logic is applied here ---
			var factor = rule.get("factor", 1.0)
			# If shields are present, they reduce the penalty's effect.
			# A shield_strength of 1.0 would completely negate the penalty.
			if shield_strength > 0.0:
				var penalty_amount = 1.0 - factor
				var effective_penalty = penalty_amount * (1.0 - clampf(shield_strength, 0.0, 1.0))
				factor = 1.0 - effective_penalty
			
			for key in output: output[key] *= factor
		_:
			pass
