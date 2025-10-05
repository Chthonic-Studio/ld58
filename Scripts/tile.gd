# The script for an individual tile instance in the scene tree.
# Its primary role is to hold data, manage its visual representation (via its children),
# and handle direct player input.
class_name Tile
extends Node2D

# Emitted when this tile is clicked, sending its grid position.
signal tile_clicked(pos: Vector2i)
@onready var input_area: Area2D = $InputArea

# The grid position of this tile. Set by the GridManager upon placement.
var grid_position: Vector2i

# A reference to the TileData resource that defines this tile's properties.
var tile_data: Tile_Data


# How to use:
# When the GridManager creates a Tile scene instance, it should call this function
# to properly initialize it with its data and position.
func initialize(pos: Vector2i, data: Tile_Data) -> void:
	self.grid_position = pos
	self.tile_data = data
	
	var sprite: Sprite2D = $Sprite2D
	if sprite:
		sprite.texture = tile_data.texture
	
	# --- NEW: Connect the input event signal from the Area2D ---
	input_area.input_event.connect(_on_input_event)

func _on_input_event(_viewport, event: InputEvent, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		tile_clicked.emit(grid_position)
