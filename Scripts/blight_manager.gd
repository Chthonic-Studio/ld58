#
# File: Scripts/blight_manager.gd
#
class_name BlightManager
extends Node

# --- SIGNALS ---
signal tile_blighted(pos: Vector2i)


# --- EXPORTS & CONFIGURATION ---
@export var spawn_interval_sec: float = 15.0
@export var spread_interval_sec: float = 4.0


# --- NODE REFERENCES ---
@onready var _spawn_timer: Timer = $SpawnTimer
@onready var _spread_timer: Timer = $SpreadTimer
@onready var _grid_manager: GridManager = get_node("../GridManager")


# --- PROPERTIES ---
var _blighted_cells: Dictionary = {}
var _protected_cells: Dictionary = {}
var _neighbor_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


# --- GODOT ENGINE FUNCTIONS ---
func _ready() -> void:
	# Configure timers
	_spawn_timer.wait_time = spawn_interval_sec
	_spread_timer.wait_time = spread_interval_sec
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_spread_timer.timeout.connect(_on_spread_timer_timeout)

	# Defer the signal connection to avoid startup race conditions.
	# This is a robust and simple way to ensure the GridManager is ready.
	if is_instance_valid(_grid_manager):
		_grid_manager.tile_placed.connect.call_deferred(_on_tile_placed)
	else:
		push_error("BlightManager could not find a valid GridManager node.")
		return

	# Use a one-shot timer to start the Blight after a grace period.
	get_tree().create_timer(5.0, false).timeout.connect(func():
		print("BlightManager: Timers started. The Blight is now active.")
		_spawn_timer.start()
		_spread_timer.start()
	)


# --- SPREAD/SPAWN LOGIC ---
func _on_spawn_timer_timeout() -> void:
	# --- CHANGE: This logic is now much more specific ---
	var valid_targets: Array[Vector2i]
	var all_placeable_tiles: Array[Vector2i]

	for pos in _grid_manager.grid:
		# We're interested in all tiles that are not the Core
		if not _grid_manager.grid[pos].tile_data.tags.has(&"core_tile"):
			all_placeable_tiles.append(pos)
			# A valid target is a non-core tile that is not yet blighted or protected
			if not _blighted_cells.has(pos) and not _protected_cells.has(pos):
				valid_targets.append(pos)
	
	var target_pos: Vector2i
	# If there are still non-core tiles to blight, pick one.
	if not valid_targets.is_empty():
		target_pos = valid_targets.pick_random()
	# Else, if all non-core tiles are blighted, the ONLY target left is the Core.
	elif all_placeable_tiles.size() == _blighted_cells.size() and _grid_manager.grid.has(_grid_manager.core_pos):
		target_pos = _grid_manager.core_pos
	# Otherwise, do nothing.
	else:
		return
	
	_blight_cell(target_pos)


func _on_spread_timer_timeout() -> void:
	if _blighted_cells.is_empty():
		return
		
	var frontier: Array[Vector2i]
	for blighted_pos in _blighted_cells:
		for dir in _neighbor_dirs:
			var neighbor_pos = blighted_pos + dir
			
			if _grid_manager.grid.has(neighbor_pos) and not _blighted_cells.has(neighbor_pos) and not _protected_cells.has(neighbor_pos):
				if not frontier.has(neighbor_pos):
					frontier.append(neighbor_pos)

	if frontier.is_empty():
		return
		
	var spread_target_pos: Vector2i = frontier.pick_random()
	_blight_cell(spread_target_pos)


func _blight_cell(pos: Vector2i) -> void:
	if _blighted_cells.has(pos):
		return

	_blighted_cells[pos] = true
	tile_blighted.emit(pos)
	print("Blight has consumed tile at: ", pos)


# --- SIGNAL HANDLERS ---
# This function now listens to ANY tile being placed.
func _on_tile_placed(pos: Vector2i, tile_data: Tile_Data) -> void:
	# It inspects the data to see if it should react.
	for tag in tile_data.tags:
		if tag.begins_with("radius:"):
			var radius_str = tag.split(":")[1]
			if radius_str.is_valid_int():
				var radius = radius_str.to_int()
				_add_defensive_zone(pos, radius)
				break


# --- PRIVATE FUNCTIONS ---
func _add_defensive_zone(center_pos: Vector2i, radius: int) -> void:
	print("BlightManager: Defensive zone of radius %d added at %s" % [radius, center_pos])
	for y in range(center_pos.y - radius, center_pos.y + radius + 1):
		for x in range(center_pos.x - radius, center_pos.x + radius + 1):
			var cell = Vector2i(x, y)
			_protected_cells[cell] = true
