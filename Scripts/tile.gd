# The script for an individual tile instance in the scene tree.
# Its primary role is to hold data, manage its visual representation (via its children),
# and handle direct player input.
class_name Tile
extends Node2D

# Emitted when this tile is clicked, sending its grid position.
signal tile_clicked(pos: Vector2i)

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
