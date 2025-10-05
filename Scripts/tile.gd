# The script for an individual tile instance in the scene tree.
# Its primary role is to hold data, manage its visual representation (via its children),
# and handle direct player input.
class_name Tile
extends Node2D

signal tile_clicked(pos: Vector2i)

# --- Node References ---
@onready var input_area: Area2D = $InputArea
@onready var sprite: Sprite2D = $Sprite2D

# --- Properties ---
var grid_position: Vector2i
var tile_data: Tile_Data
# --- NEW: Properties to manage blight state ---
var is_blighted: bool = false
var blight_progress: float = 0.0 # 0.0 to 1.0


# --- GODOT ENGINE FUNCTIONS & INITIALIZATION ---
func initialize(pos: Vector2i, data: Tile_Data) -> void:
	self.grid_position = pos
	self.tile_data = data
	
	if sprite:
		sprite.texture = tile_data.texture
	
	input_area.input_event.connect(_on_input_event)

# --- PUBLIC FUNCTIONS ---

# Called by GridManager to update this tile's blight state.
func set_blight_progress(progress: float) -> void:
	# REASONING: This function encapsulates the tile's response to blight.
	# It updates the internal state and the visual shader in one go.
	blight_progress = clampf(progress, 0.0, 1.0)
	is_blighted = blight_progress > 0.0
	
	# If the tile has a shader material, update its 'progress' uniform.
	if sprite.material is ShaderMaterial:
		sprite.material.set_shader_parameter("progress", blight_progress)

# --- SIGNAL HANDLERS ---
func _on_input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	# Left-click to interact (e.g., upgrade Core).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		tile_clicked.emit(grid_position)
		
	# --- NEW: Right-click to destroy a blighted tile ---
	# REASONING: Implements the user's request for a manual "pruning" mechanic.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		if is_blighted:
			# The tile tells the GridManager it wants to be removed.
			# This follows our rule of not letting nodes delete themselves from a manager.
			get_node("../").remove_tile(grid_position, true) # Assuming GridManager has remove_tile
