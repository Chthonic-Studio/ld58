# Dynamically creates UI buttons for each placeable tile in the game.
# It gets the list of tiles from the ResourceCatalog and creates a button for each one.
extends VBoxContainer # Or any other container node you prefer.

# --- Signals ---
# Emitted when a tile button is pressed, providing the data for that tile.
signal tile_selected(tile_data: Tile_Data)


# --- Godot Engine Functions ---

# Called when the node enters the scene tree.
func _ready() -> void:
	# --- How to use: ---
	# 1. Attach this script to a container node (like VBoxContainer) inside your main_ui.tscn.
	# 2. This script will automatically populate its parent container with buttons.
	
	# Use call_deferred to wait one frame, ensuring the ResourceCatalog has finished loading.
	call_deferred("_populate_build_buttons")


# --- Private Functions ---

# Fetches all Tile_Data resources from the ResourceCatalog and creates a button for each.
func _populate_build_buttons() -> void:
	# Get all available tile data, sorted by display name for consistent order.
	var all_tiles: Array = ResourceCatalog.tiles.values()
	all_tiles.sort_custom(func(a, b): return a.display_name < b.display_name)
	
	for tile_data in all_tiles:
		# --- CHANGE: Skip any tile that is marked as unbuildable ---
		if tile_data.tags.has(&"unbuildable"):
			continue

		# For each tile, create a new button.
		var button := Button.new()
# --- Signal Handlers ---

# This function is called when any of the dynamically created tile buttons are pressed.
func _on_tile_button_pressed(tile_data: Tile_Data) -> void:
	# Check if the player can actually afford this tile before emitting the signal.
	if ResourceManager.can_afford(tile_data.cost):
		print("Selected tile: ", tile_data.display_name)
		tile_selected.emit(tile_data)
	else:
		print("Cannot afford tile: ", tile_data.display_name)
		# In a real game, you would add feedback here, like a sound or visual cue.
