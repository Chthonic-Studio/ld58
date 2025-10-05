# The script for an individual tile instance in the scene tree.
# Its primary role is to hold data, manage its visual representation (via its children),
# and handle direct player input.
class_name Tile
extends Node2D

# --- FIX: The signal was being emitted but was never declared. ---
# This is the fundamental cause of the cascading errors.
signal tile_clicked(pos: Vector2i)

# --- Node References ---
@onready var input_area: Area2D = $InputArea

# --- Properties ---
# The grid position of this tile. Set by the GridManager upon placement.
var grid_position: Vector2i

# A reference to the TileData resource that defines this tile's properties.
var tile_data: Tile_Data


# --- GODOT ENGINE FUNCTIONS & INITIALIZATION ---

# How to use:
# When the GridManager creates a Tile scene instance, it should call this function
# to properly initialize it with its data and position.
func initialize(pos: Vector2i, data: Tile_Data) -> void:
	self.grid_position = pos
	self.tile_data = data
	
	var sprite: Sprite2D = $Sprite2D
	if sprite:
		sprite.texture = tile_data.texture
	
	# Connect the input event signal from the Area2D. This is the correct place for this.
	input_area.input_event.connect(_on_input_event)


# --- SIGNAL HANDLERS ---

# This function is called when the Area2D detects any input event.
func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	# We only care about the left mouse button being pressed down.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		# The tile's only job is to announce that it was clicked and where it is.
		# It does not decide what the click means.
		tile_clicked.emit(grid_position)
