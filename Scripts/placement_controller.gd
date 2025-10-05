# This node acts as the intermediary between the UI and the game world.
extends Node

# --- Node References ---
var _grid_manager: GridManager
var _main_ui: Control

# --- State Variables ---
var _selected_tile_data: Tile_Data = null


# --- GODOT ENGINE FUNCTIONS ---
func _ready() -> void:
	_grid_manager = get_node("../GridManager")
	_main_ui = get_node("../MainUI")
	
	if not _grid_manager:
		push_error("PlacementController could not find GridManager.")
		return
	if not _main_ui:
		push_error("PlacementController could not find MainUI.")
		return
		
	_main_ui.tile_to_build_selected.connect(_on_main_ui_tile_to_build_selected)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var grid_pos: Vector2i = _grid_manager.world_to_grid_coords(event.position)
		
		# If we have a tile selected for building, try to place it.
		if _selected_tile_data != null:
			if _grid_manager.place_tile(grid_pos, _selected_tile_data):
				ResourceManager.spend_resources(_selected_tile_data.cost)
			# Deselect after attempting to place, successful or not.
			_selected_tile_data = null
		
		# --- NEW: If no tile is selected for building, check for interaction ---
		else:
			# Check if the clicked tile is the Core
			if _grid_manager.grid.has(grid_pos) and _grid_manager.grid[grid_pos].tile_data.tags.has(&"core_tile"):
				_grid_manager.attempt_upgrade_core(grid_pos)
				
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		_selected_tile_data = null
		print("Build selection cancelled.")

# --- SIGNAL HANDLERS ---
func _on_main_ui_tile_to_build_selected(tile_data: Tile_Data) -> void:
	_selected_tile_data = tile_data
	print("Ready to place: ", tile_data.display_name)
