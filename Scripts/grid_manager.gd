#
# File: Scripts/grid_manager.gd
#
# Manages the 2D grid state, tile placement, and the complex synergy calculation logic.
# It now also applies the mechanical effects of progressive blight corruption.
class_name GridManager
extends Node2D

# --- EXPORTS & CONFIGURATION ---
@export var cell_size := Vector2i(64, 64)
@export var grid_dimensions := Vector2i(20, 15)
@export var tile_scene: PackedScene

# --- SIGNALS ---
signal tile_placed(pos: Vector2i, tile_data: Tile_Data)
signal tile_removed(pos: Vector2i)
signal generation_recalculated(total_generation: Dictionary, per_tile_generation: Dictionary)
signal all_tiles_blighted

# --- PROPERTIES ---
var grid: Dictionary = {}
var neighbor_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
var core_pos: Vector2i
var _grid_bounds: Rect2i

# --- GODOT ENGINE FUNCTIONS ---
func _ready() -> void:
	# How to use:
	# This node should be a child of a "GridContainer" for centering.
	# It requires the BlightManager to be in the scene to connect signals.
	var grid_pixel_size = grid_dimensions * cell_size
	self.position = -(grid_pixel_size / 2)
	
	_grid_bounds = Rect2i(-(grid_dimensions / 2), grid_dimensions)

	# --- REASONING for New Connections ---
	# We find the BlightManager once and connect to its signals.
	# This is the core of the new decoupled architecture. GridManager now reacts
	# to blight events instead of being directly manipulated.
	var blight_manager = get_node_or_null("/root/Main/BlightManager")
	if blight_manager:
		blight_manager.blight_progress_updated.connect(_on_blight_progress_updated)
		blight_manager.blight_cleansed.connect(_on_blight_cleansed)
	else:
		push_warning("GridManager could not find BlightManager. Blight system will not function.")

	call_deferred("_place_initial_core")

# --- PUBLIC FUNCTIONS ---

# Returns the grid's boundaries in grid coordinates. Used by BlightManager.
func get_grid_bounds() -> Rect2i:
	return _grid_bounds

func place_tile(pos: Vector2i, tile_data: Tile_Data) -> bool:
	if not _grid_bounds.has_point(pos):
		printerr("GridManager: Attempted to place tile out-of-bounds at %s" % str(pos))
		return false
	
	if grid.has(pos):
		printerr("GridManager: Attempted to place tile on occupied cell %s" % str(pos))
		return false
	
	# REASONING: The internal record for a tile now includes 'blight_progress'.
	grid[pos] = {
		"tile_data": tile_data,
		"blight_progress": 0.0,
		"node_instance": null
	}
	
	if tile_scene:
		var tile_instance: Tile = tile_scene.instantiate()
		add_child(tile_instance)
		tile_instance.position = (pos * cell_size) + (cell_size / 2)
		tile_instance.initialize(pos, tile_data)
		
		# The GridManager now listens for clicks, not a separate controller.
		tile_instance.tile_clicked.connect(_on_any_tile_clicked)
		
		grid[pos].node_instance = tile_instance
	
	tile_placed.emit(pos, tile_data)
	_recalculate_generation()
	return true

func remove_tile(pos: Vector2i) -> void:
	# REASONING: Centralizes tile removal logic. This is called by a Tile node
	# when it is right-clicked.
	if not grid.has(pos):
		return

	if is_instance_valid(grid[pos].node_instance):
		grid[pos].node_instance.queue_free()
	
	grid.erase(pos)
	print("GridManager: Removed tile at %s" % str(pos))
	
	# Announce that the grid has changed so other systems (like BlightManager) can react.
	tile_removed.emit(pos)
	_recalculate_generation()

func world_to_grid_coords(world_pos: Vector2) -> Vector2i:
	var local_pos = to_local(world_pos)
	return Vector2i(floor(local_pos.x / cell_size.x), floor(local_pos.y / cell_size.y))

# --- SIGNAL HANDLERS ---

func _on_blight_progress_updated(pos: Vector2i, progress: float) -> void:
	# REASONING: This handler synchronizes the GridManager's state with the BlightManager's.
	if not grid.has(pos):
		return
		
	var tile_record = grid[pos]
	tile_record.blight_progress = progress
	
	# Command the visual tile node to update its shader.
	var tile_node: Tile = tile_record.node_instance
	if is_instance_valid(tile_node):
		tile_node.set_blight_progress(progress)
		
	# A change in blight progress directly affects generation, so we must recalculate.
	_recalculate_generation()
	
	if progress >= 1.0:
		_check_for_blight_game_over()

func _on_blight_cleansed(pos: Vector2i) -> void:
	# When a blight is fully removed, reset the progress to 0.
	_on_blight_progress_updated(pos, 0.0)

func _on_any_tile_clicked(pos: Vector2i) -> void:
	# Upgrading the core is still handled here.
	if grid.has(pos) and grid[pos].tile_data.tags.has(&"core_tile"):
		attempt_upgrade_core(pos)

# --- PRIVATE LOGIC ---
func _recalculate_generation() -> void:
	var total_generation := {}
	var per_tile_generation := {}
	for pos in grid.keys():
		var inst = grid[pos]
		var tile_gen: Dictionary = _compute_tile_generation(pos, inst)
		per_tile_generation[pos] = tile_gen
		for resource_key in tile_gen:
			total_generation[resource_key] = total_generation.get(resource_key, 0.0) + tile_gen[resource_key]
	generation_recalculated.emit(total_generation, per_tile_generation)

func _compute_tile_generation(pos: Vector2i, inst: Dictionary) -> Dictionary:
	# The 'disabled' flag is now replaced by checking blight_progress.
	if inst.blight_progress >= 1.0:
		return {}

	var td: Tile_Data = inst.tile_data
	var output: Dictionary = td.base_generation.duplicate()

	# ... (Synergy calculation logic remains the same)
	
	# --- REASONING for Mechanical Effect of Blight ---
	# After all synergies are calculated, we apply the blight penalty.
	# This scales the tile's final output based on its corruption level.
	if inst.blight_progress > 0.0:
		var penalty_factor = 1.0 - inst.blight_progress
		for key in output:
			output[key] *= penalty_factor

	return output

# ... (other functions like _place_initial_core, attempt_upgrade_core, etc.)
func _place_initial_core() -> void:
	var core_data: Tile_Data = ResourceCatalog.tiles.get(&"core")
	if not core_data:
		push_error("GridManager: Could not find 'core' TileData in ResourceCatalog!")
		return
	
	core_pos = Vector2i.ZERO
	place_tile(core_pos, core_data)
	
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


func _check_for_blight_game_over() -> void:
	for pos in grid:
		var tile = grid[pos]
		if not tile.tile_data.tags.has(&"core_tile") and tile.blight_progress < 1.0:
			return
	
	if grid.size() > 1:
		all_tiles_blighted.emit()
