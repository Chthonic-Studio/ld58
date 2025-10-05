#
# File: Scripts/synergy_visualizer.gd
#
# --- HOW TO USE ---
# 1. Attach this script to a Node2D named 'SynergyVisualizer' in main.tscn.
# 2. Create a 'synergy_glow.tscn' scene (e.g., a Sprite2D with a glow texture and Additive blend mode).
# 3. Drag 'synergy_glow.tscn' into the 'Glow Effect Scene' export property in the Inspector.
#
class_name SynergyVisualizer
extends Node2D

# --- EXPORTS ---
## The scene to instantiate for the glow effect.
@export var glow_effect_scene: PackedScene

# --- NODE REFERENCES ---
var _grid_manager: GridManager

# --- PROPERTIES ---
# A pool of glow nodes to reuse for efficiency.
var _glow_pool: Array[Node2D] = []
var _active_glows: int = 0


# --- GODOT ENGINE FUNCTIONS ---
func _ready() -> void:
	# --- REASONING for Z-Index ---
	# We set the z_index to be higher than the GridManager's. Since the Tile nodes
	# are children of GridManager (z_index=0), this ensures our glow effects (children
	# of this node) are always drawn on top of the tiles.
	self.z_index = 5
	
	_grid_manager = get_node("../GridManager")
	if not _grid_manager:
		push_error("SynergyVisualizer could not find GridManager node!")
		return
	
	if not glow_effect_scene:
		push_error("SynergyVisualizer is missing the Glow Effect Scene!")
		return
	
	# Connect to the signal that tells us when to update the visuals.
	_grid_manager.generation_recalculated.connect(_on_generation_recalculated)


# --- SIGNAL HANDLERS ---
func _on_generation_recalculated(_total_generation: Dictionary, per_tile_generation: Dictionary) -> void:
	_update_synergy_glows(per_tile_generation)


# --- PRIVATE FUNCTIONS ---
# This function updates which tiles should be glowing.
func _update_synergy_glows(per_tile_generation: Dictionary) -> void:
	# First, hide all existing glows. We'll make them visible again if they're still needed.
	for i in range(_active_glows):
		_glow_pool[i].visible = false
	_active_glows = 0

	# Iterate through all tiles that reported generation data.
	for pos in per_tile_generation:
		var tile_instance = _grid_manager.grid.get(pos)
		if not tile_instance: continue

		var tile_data: Tile_Data = tile_instance.tile_data
		var current_generation = per_tile_generation[pos]

		# Compare the tile's current generation with its base generation.
		var is_synergized = false
		for resource_key in current_generation:
			var base_value = tile_data.base_generation.get(resource_key, 0.0)
			# If any resource is generating more than its base value, it's synergized.
			if current_generation[resource_key] > base_value:
				is_synergized = true
				break
		
		# If the tile is synergized, show a glow on it.
		if is_synergized:
			var glow_position = (pos * _grid_manager.cell_size) + (_grid_manager.cell_size / 2)
			_show_glow_at(glow_position)


# Manages the pool of glow effect nodes.
func _show_glow_at(pos: Vector2) -> void:
	var glow_node: Node2D
	
	# Reuse a node from the pool if available.
	if _active_glows < _glow_pool.size():
		glow_node = _glow_pool[_active_glows]
	# Otherwise, create a new one.
	else:
		glow_node = glow_effect_scene.instantiate()
		add_child(glow_node)
		_glow_pool.append(glow_node)
	
	# Position the glow and make it visible.
	glow_node.position = pos
	glow_node.visible = true
	_active_glows += 1
