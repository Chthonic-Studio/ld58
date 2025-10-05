#
# File: Scripts/synergy_visualizer.gd
#
class_name SynergyVisualizer
extends Node2D

# --- EXPORTS & CONFIGURATION ---
@export var line_color: Color = Color.CYAN
@export var line_width: float = 2.0

# --- NODE REFERENCES ---
var _grid_manager: GridManager

# --- PROPERTIES ---
# An array to store pairs of grid positions that have a synergy.
var _synergy_links: Array[Array] = []

# --- GODOT ENGINE FUNCTIONS ---
func _ready() -> void:
	# --- How to use: ---
	# 1. Create a new script at `Scripts/synergy_visualizer.gd` and paste this content.
	# 2. In the `main.tscn` scene, add a new `Node2D` named `SynergyVisualizer`.
	# 3. Attach this script to the `SynergyVisualizer` node.
	
	_grid_manager = get_node("../GridManager") # Adjust path if needed
	if not _grid_manager:
		push_error("SynergyVisualizer could not find GridManager node!")
		return
	
	# Connect to the signal that tells us the grid's output has been recalculated.
	# This is the perfect time to check for new synergy links.
	_grid_manager.generation_recalculated.connect(_on_generation_recalculated)
	
	# We also need to clear the lines if a tile is removed.
	_grid_manager.tile_removed.connect(func(_pos): queue_redraw())


func _draw() -> void:
	# This function is called automatically by the engine whenever queue_redraw() is called.
	# It iterates through all the stored links and draws them.
	if not is_instance_valid(_grid_manager):
		return
		
	for link in _synergy_links:
		# --- CORRECTION ---
		# Replaced the incorrect call to map_to_local with manual coordinate calculation.
		# This logic now correctly mirrors how the GridManager itself places tile nodes.
		# We take the grid coordinate, multiply by the cell size to get the top-left
		# corner, and then add half the cell size to find the center.
		var start_pos: Vector2 = (link[0] * _grid_manager.cell_size) + (_grid_manager.cell_size / 2)
		var end_pos: Vector2 = (link[1] * _grid_manager.cell_size) + (_grid_manager.cell_size / 2)
		draw_line(start_pos, end_pos, line_color, line_width, true)


# --- SIGNAL HANDLERS ---
func _on_generation_recalculated(_total_generation: Dictionary, _per_tile_generation: Dictionary) -> void:
	_update_synergy_links()
	queue_redraw() # Tell Godot to call _draw() on the next frame.


# --- PRIVATE FUNCTIONS ---
func _update_synergy_links() -> void:
	_synergy_links.clear()
	
	if not is_instance_valid(_grid_manager) or _grid_manager.grid.is_empty():
		return

	# We must iterate through every tile and check its neighbors for synergies.
	for pos in _grid_manager.grid:
		var tile_instance = _grid_manager.grid[pos]
		var tile_data: Tile_Data = tile_instance.tile_data
		
		# If this tile has no rules, it can't initiate a synergy.
		if tile_data.synergy_rules.is_empty():
			continue
			
		for dir in _grid_manager.neighbor_dirs:
			var neighbor_pos = pos + dir
			
			# Check if neighbor exists and has a category that our tile reacts to.
			if _grid_manager.grid.has(neighbor_pos):
				var neighbor_instance = _grid_manager.grid[neighbor_pos]
				var neighbor_data: Tile_Data = neighbor_instance.tile_data
				
				if tile_data.synergy_rules.has(neighbor_data.category):
					# A synergy exists! Add the link.
					_synergy_links.append([pos, neighbor_pos])
