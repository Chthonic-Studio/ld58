#
# File: Scripts/synergy_visualizer.gd
#
class_name SynergyVisualizer
extends Node2D

# --- PRELOADS & EXPORTS ---
# How to use:
# 1. Replace the old SynergyVisualizer script content with this.
# 2. Create the `synergy_link.tscn` scene as specified.
# 3. Drag `synergy_link.tscn` from the FileSystem dock into the `Synergy Link Scene`
#    export property in the Inspector for the SynergyVisualizer node.

## The scene for a single synergy link line.
@export var synergy_link_scene: PackedScene

# --- NODE REFERENCES ---
var _grid_manager: GridManager

# --- PROPERTIES ---
# A pool of Line2D nodes to reuse for drawing links. This is more
# efficient than creating/destroying nodes constantly.
var _link_pool: Array[Line2D] = []
var _active_links: int = 0


# --- GODOT ENGINE FUNCTIONS ---
func _ready() -> void:
	# --- FIX: Ensure this node draws on top of the tiles. ---
	# The default z_index is 0, the same as the tiles. By setting it higher,
	# we guarantee that any children of this node (the Line2D links) will
	# be rendered after, and thus on top of, the tile sprites.
	self.z_index = 10
	
	_grid_manager = get_node("../GridManager")
	if not _grid_manager:
		push_error("SynergyVisualizer could not find GridManager node!")
		return
	
	if not synergy_link_scene:
		push_error("SynergyVisualizer is missing the Synergy Link Scene!")
		return
	
	# Connect to the signals that tell us when to redraw the links.
	_grid_manager.generation_recalculated.connect(_on_generation_recalculated)
	_grid_manager.tile_removed.connect(_on_generation_recalculated.bind({}, {}))


# --- SIGNAL HANDLERS ---
func _on_generation_recalculated(_total_generation: Dictionary, _per_tile_generation: Dictionary) -> void:
	# This function is now the single point of update for the visuals.
	_update_synergy_links()


# --- PRIVATE FUNCTIONS ---
# This function redraws all synergy links based on the current grid state.
func _update_synergy_links() -> void:
	# Hide all currently active links before redrawing.
	for i in range(_active_links):
		_link_pool[i].visible = false
	_active_links = 0
	
	if not is_instance_valid(_grid_manager) or _grid_manager.grid.is_empty():
		return

	# Iterate through every tile and check its neighbors for synergies.
	for pos in _grid_manager.grid:
		# Skip disabled tiles, as they shouldn't show active synergies.
		if _grid_manager.grid[pos].disabled:
			continue
			
		var tile_data: Tile_Data = _grid_manager.grid[pos].tile_data
		if tile_data.synergy_rules.is_empty():
			continue
			
		for dir in _grid_manager.neighbor_dirs:
			var neighbor_pos = pos + dir
			
			# Check if a valid, non-disabled neighbor exists that our tile reacts to.
			if _grid_manager.grid.has(neighbor_pos) and not _grid_manager.grid[neighbor_pos].disabled:
				var neighbor_data: Tile_Data = _grid_manager.grid[neighbor_pos].tile_data
				
				if tile_data.synergy_rules.has(neighbor_data.category):
					# A synergy exists! Draw the link.
					var start_world_pos = (pos * _grid_manager.cell_size) + (_grid_manager.cell_size / 2)
					var end_world_pos = (neighbor_pos * _grid_manager.cell_size) + (_grid_manager.cell_size / 2)
					_draw_link(start_world_pos, end_world_pos)


# Draws a single link between two points using a Line2D from the pool.
func _draw_link(start_pos: Vector2, end_pos: Vector2) -> void:
	var link_node: Line2D
	
	# Do we have an available node in our pool?
	if _active_links < _link_pool.size():
		link_node = _link_pool[_active_links]
	else:
		# If not, create a new one and add it to the pool.
		if not synergy_link_scene: return
		link_node = synergy_link_scene.instantiate()
		add_child(link_node)
		_link_pool.append(link_node)
	
	# Configure the Line2D node and make it visible.
	link_node.points = [start_pos, end_pos]
	link_node.visible = true
	_active_links += 1
