#
# File: Scripts/blight_manager.gd
#
# Manages the entire lifecycle of the Blight, from spawning and spreading to
# tracking the progressive corruption of individual tiles. It acts as a
# thinking antagonist, making strategic decisions based on the player's actions.
class_name BlightManager
extends Node

# --- SIGNALS ---
# Emitted when a tile's blight progress has changed.
# GridManager listens to this to apply visual and mechanical effects.
signal blight_progress_updated(pos: Vector2i, progress: float)
# Emitted when a blight is completely removed from a tile.
signal blight_cleansed(pos: Vector2i)

# --- EXPORTS & CONFIGURATION ---
@export_group("Blight Timings")
## The base time between Blight actions (spawning or spreading). This value will decrease over time.
@export var base_action_interval: float = 5.0
## The base time it takes for a blighted tile to go from 0% to 100% corruption.
@export var base_corruption_duration: float = 20.0
## How many times the Blight will spread before trying to spawn a new infection.
@export var spreads_per_spawn: int = 5

@export_group("Blight Scaling")
## Every X seconds, the Blight's action speed increases.
@export var spawn_scaling_interval: float = 20.0
## The percentage increase in action speed (0.1 = 10%).
@export var spawn_scaling_factor: float = 0.1
## Every Y seconds, the Blight's corruption speed increases.
@export var spread_scaling_interval: float = 30.0
## The percentage increase in corruption speed (0.2 = 20%).
@export var spread_scaling_factor: float = 0.2

# --- NODE REFERENCES ---
# This script requires three child Timer nodes: "ActionTimer", "SpawnScalerTimer", "SpreadScalerTimer".
@onready var action_timer: Timer = $ActionTimer
@onready var spawn_scaler_timer: Timer = $SpawnScalerTimer
@onready var spread_scaler_timer: Timer = $SpreadScalerTimer

# Node path must be set in the Inspector, as per project standards.
@export var grid_manager: GridManager

# --- PROPERTIES ---
# This dictionary now stores the state of every blighted cell.
# Key: Vector2i(pos), Value: Dictionary representing the BlightInstance { "progress": float }
var _blighted_cells: Dictionary = {}

# This dictionary now stores the state of each Purifier tile.
# Key: Vector2i(pos), Value: Dictionary representing the PurifierInstance { "radius": int, "start_time": int }
var _purifier_zones: Dictionary = {}

var _neighbor_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
var _spread_counter: int = 0
var _current_action_interval: float
var _current_corruption_speed: float

# --- GODOT ENGINE FUNCTIONS ---
func _ready() -> void:
	# --- How to use: ---
	# 1. Attach this script to a "BlightManager" node.
	# 2. Add three child Timer nodes: "ActionTimer", "SpawnScalerTimer", "SpreadScalerTimer".
	# 3. In the Inspector, link the 'grid_manager' export to the GridManager node in the scene.
	
	if not is_instance_valid(grid_manager):
		push_error("BlightManager: GridManager node is not assigned!")
		return
	
	grid_manager.tile_placed.connect(_on_tile_placed)
	grid_manager.tile_removed.connect(_on_tile_removed)
	
	_current_action_interval = base_action_interval
	_current_corruption_speed = 1.0 / base_corruption_duration # Corruption per second
	
	action_timer.wait_time = _current_action_interval
	action_timer.timeout.connect(_on_action_timer_timeout)
	
	spawn_scaler_timer.wait_time = spawn_scaling_interval
	spawn_scaler_timer.timeout.connect(_on_spawn_scaler_timeout)
	
	spread_scaler_timer.wait_time = spread_scaling_interval
	spread_scaler_timer.timeout.connect(_on_spread_scaler_timeout)
	
	get_tree().create_timer(10.0, false).timeout.connect(func():
		print("BlightManager: The Blight is now active.")
		_spawn_new_blight()
		action_timer.start()
		spawn_scaler_timer.start()
		spread_scaler_timer.start()
	)

func _process(delta: float) -> void:
	# Use _process to handle the continuous progression of blight and purifier decay.
	if _blighted_cells.is_empty():
		return
		
	var cells_to_cleanse: Array[Vector2i] = []
	for pos in _blighted_cells:
		var blight_instance: Dictionary = _blighted_cells[pos]
		var protection_factor = _get_protection_at(pos)
		
		# If a fully effective purifier is present, the blight recedes.
		if protection_factor >= 1.0:
			blight_instance.progress -= _current_corruption_speed * delta
		else:
			blight_instance.progress += _current_corruption_speed * delta * (1.0 - protection_factor)

		blight_instance.progress = clampf(blight_instance.progress, 0.0, 1.0)
		
		if blight_instance.progress <= 0.0:
			cells_to_cleanse.append(pos)
		
		blight_progress_updated.emit(pos, blight_instance.progress)
		
	for pos in cells_to_cleanse:
		_cleanse_cell(pos)

# --- ACTION LOGIC ---
func _on_action_timer_timeout() -> void:
	if _spread_counter >= spreads_per_spawn:
		_spawn_new_blight()
	else:
		_spread_to_new_cell()
	
	_spread_counter += 1

func _spawn_new_blight() -> void:
	_spread_counter = 0
	
	var attractors = _find_attractor_tiles()
	if not attractors.is_empty():
		var target_attractor = attractors.pick_random()
		var spawn_pos = _find_empty_neighbor(target_attractor)
		if _is_valid_target(spawn_pos):
			print("BlightManager: Spawning near attractor at %s." % str(spawn_pos))
			_start_blighting_cell(spawn_pos)
			return
			
	var target_zone = _find_best_target_zone()
	if target_zone != Vector2i.ZERO or not grid_manager.grid.is_empty(): # Check if a valid zone was found
		var spawn_pos = _find_random_point_in_zone(target_zone)
		if _is_valid_target(spawn_pos):
			print("BlightManager: Spawning in remote zone around %s." % str(spawn_pos))
			_start_blighting_cell(spawn_pos)
			return

func _spread_to_new_cell() -> void:
	var frontier = _get_blight_frontier()
	if frontier.is_empty():
		return
		
	frontier.sort_custom(func(a, b):
		return a.distance_squared_to(grid_manager.core_pos) < b.distance_squared_to(grid_manager.core_pos)
	)
	var target_pos = frontier[0]
	
	print("BlightManager: Spreading to new cell at %s." % str(target_pos))
	_start_blighting_cell(target_pos)

func _start_blighting_cell(pos: Vector2i) -> void:
	if not _is_valid_target(pos): return
	_blighted_cells[pos] = {"progress": 0.0}

func _cleanse_cell(pos: Vector2i) -> void:
	if _blighted_cells.has(pos):
		_blighted_cells.erase(pos)
		blight_cleansed.emit(pos)
		print("BlightManager: Cell at %s has been cleansed." % str(pos))

# --- SCALING LOGIC ---
func _on_spawn_scaler_timeout() -> void:
	_current_action_interval *= (1.0 - spawn_scaling_factor)
	action_timer.wait_time = _current_action_interval
	print("BlightManager: Action speed increased. New interval: %s" % _current_action_interval)

func _on_spread_scaler_timeout() -> void:
	_current_corruption_speed *= (1.0 + spread_scaling_factor)
	print("BlightManager: Corruption speed increased. New speed: %s" % _current_corruption_speed)

# --- SIGNAL HANDLERS ---
func _on_tile_placed(pos: Vector2i, tile_data: Tile_Data) -> void:
	for tag in tile_data.tags:
		if tag.begins_with("radius:"):
			var radius_str = tag.split(":")[1]
			if radius_str.is_valid_int():
				_purifier_zones[pos] = {
					"radius": radius_str.to_int(),
					"start_time": Time.get_ticks_msec()
				}
				print("BlightManager: Purifier registered at %s." % str(pos))
				break

func _on_tile_removed(pos: Vector2i) -> void:
	if _blighted_cells.has(pos):
		_cleanse_cell(pos)
	if _purifier_zones.has(pos):
		_purifier_zones.erase(pos)
		print("BlightManager: Purifier at %s was removed." % str(pos))

# --- PRIVATE HELPER FUNCTIONS ---
func _find_attractor_tiles() -> Array[Vector2i]:
	var attractors: Array[Vector2i] = []
	for pos in grid_manager.grid:
		if grid_manager.grid[pos].tile_data.tags.has(&"attracts_blight"):
			if not _blighted_cells.has(pos):
				attractors.append(pos)
	return attractors

func _find_best_target_zone() -> Vector2i:
	var zones: Dictionary = {}
	if grid_manager.grid.is_empty(): return Vector2i.ZERO
	
	for pos in grid_manager.grid:
		for y in range(-1, 2):
			for x in range(-1, 2):
				var zone_center = pos + Vector2i(x, y)
				zones[zone_center] = true
	
	var best_zone = zones.keys()[0]
	var max_dist = -1.0
	for zone_center in zones:
		var dist = zone_center.distance_squared_to(grid_manager.core_pos)
		if dist > max_dist:
			max_dist = dist
			best_zone = zone_center
	return best_zone

func _find_random_point_in_zone(zone_center: Vector2i) -> Vector2i:
	var attempts = 5
	for _i in range(attempts):
		var x = randi_range(-1, 1)
		var y = randi_range(-1, 1)
		var point = zone_center + Vector2i(x, y)
		if _is_valid_target(point):
			return point
	return Vector2i(-1000, -1000) # Sentinel for failure

func _find_empty_neighbor(pos: Vector2i) -> Vector2i:
	var valid_neighbors: Array[Vector2i] = []
	for dir in _neighbor_dirs:
		var neighbor_pos = pos + dir
		if _is_valid_target(neighbor_pos) and not grid_manager.grid.has(neighbor_pos):
			valid_neighbors.append(neighbor_pos)
	
	return valid_neighbors.pick_random() if not valid_neighbors.is_empty() else Vector2i(-1000, -1000)

func _get_blight_frontier() -> Array[Vector2i]:
	var frontier: Array[Vector2i] = []
	for blighted_pos in _blighted_cells:
		for dir in _neighbor_dirs:
			var neighbor_pos = blighted_pos + dir
			if _is_valid_target(neighbor_pos) and not frontier.has(neighbor_pos):
				frontier.append(neighbor_pos)
	return frontier

func _get_protection_at(pos: Vector2i) -> float:
	var max_protection: float = 0.0
	var purifiers_to_remove = []
	for purifier_pos in _purifier_zones:
		var purifier = _purifier_zones[purifier_pos]
		var age_sec = (Time.get_ticks_msec() - purifier.start_time) / 1000.0
		
		if age_sec > 30.0:
			purifiers_to_remove.append(purifier_pos)
			continue

		if pos.distance_to(purifier_pos) <= purifier.radius:
			var effectiveness = 1.0 - smoothstep(10.0, 30.0, age_sec)
			if effectiveness > max_protection:
				max_protection = effectiveness
				
	for p_pos in purifiers_to_remove:
		grid_manager.remove_tile(p_pos)

	return max_protection

func _is_valid_target(pos: Vector2i) -> bool:
	if pos == Vector2i(-1000, -1000): return false
	if not grid_manager.get_grid_bounds().has_point(pos): return false
	if _blighted_cells.has(pos): return false
	if pos == grid_manager.core_pos: return false
	return true
