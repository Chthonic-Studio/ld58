# Orchestrates the main game loop and coordinates the different manager singletons.
# This node acts as the "heartbeat" of the game, triggering the core logic on a set interval.
class_name GameManager
extends Node

signal game_over(final_score: int)

## The time in seconds between each game tick.
@export var tick_rate: float = 1.0

@export_group("Scoring")
@export var biomass_weight: float = 1.0
@export var energy_weight: float = 2.5
@export var nutrients_weight: float = 5.0
@export var time_multiplier: float = 0.1 # Score bonus per second survived

var _is_game_over: bool = false
var _time_survived: float = 0.0

# A dictionary holding the total resource generation per tick for the entire grid.
# This is updated by the GridManager.
var _total_generation: Dictionary = {}

# --- Node References ---
@onready var tick_timer: Timer = $TickTimer
@export var _blight_manager: BlightManager
@export var grid_manager : GridManager

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# How to use:
	# This script should be placed on a "GameManager" node in your main scene.
	# That node must have a child Timer node named "TickTimer".
	# The GridManager and BlightManager must also be assigned in the Inspector.
	if not grid_manager:
		push_error("GameManager could not find GridManager node!")
		return
	if not _blight_manager:
		push_error("GameManager could not find BlightManager node!")
		return
		
	# Connect to the GridManager's signal to receive updated generation values.
	grid_manager.generation_recalculated.connect(_on_grid_manager_generation_recalculated)
	
	# --- FIX: Connect to the correct, new BlightManager and GridManager signals ---
	# REASONING: We now listen for the granular progress updates from the BlightManager
	# to check if the Core tile has been fully consumed. The `all_tiles_blighted` signal
	# from the GridManager provides the primary game-over condition.
	grid_manager.all_tiles_blighted.connect(_on_all_tiles_blighted)
	_blight_manager.blight_progress_updated.connect(_on_blight_progress_updated)
	
	# Connect the timer's timeout signal to the main tick function.
	tick_timer.wait_time = tick_rate
	tick_timer.timeout.connect(_on_tick_timer_timeout)
	tick_timer.start()

func _process(delta: float) -> void:
	# Keep track of time survived for scoring, as long as the game is running.
	if not _is_game_over:
		_time_survived += delta

# --- Signal Handlers ---

# This function is called every time the TickTimer finishes its countdown.
# It represents one "turn" or "tick" of the game.
func _on_tick_timer_timeout() -> void:
	# On each tick, we take the last calculated generation values...
	if not _total_generation.is_empty():
		# ...and send them to the ResourceManager to be added to the player's totals.
		ResourceManager.add_resources(_total_generation)


# This function is called whenever the GridManager finishes recalculating synergies.
# It caches the result locally, ready for the next game tick.
func _on_grid_manager_generation_recalculated(total_generation: Dictionary, _per_tile_generation: Dictionary) -> void:
	_total_generation = total_generation
	
# --- NEW: This handler listens for progress updates from the BlightManager. ---
# It's the new way to check if the Core has been consumed.
func _on_blight_progress_updated(pos: Vector2i, progress: float) -> void:
	if _is_game_over:
		return
	
	# If the update is for the Core tile and its progress is 100%, end the game.
	if is_instance_valid(grid_manager) and pos == grid_manager.core_pos and progress >= 1.0:
		_end_game("The Core has been consumed by the Blight.")

# This handler listens for the GridManager's definitive signal that all other tiles are gone.
func _on_all_tiles_blighted() -> void:
	if _is_game_over:
		return
	_end_game("The network has been fully consumed by the Blight.")
		
# --- PRIVATE FUNCTIONS ---
func _end_game(reason: String) -> void:
	if _is_game_over:
		return
		
	print("GAME OVER! %s" % reason)
	_is_game_over = true
	
	# Stop all game timers
	tick_timer.stop()
	# REASONING: It's safer to check if the node and its children exist before trying to stop them.
	if is_instance_valid(_blight_manager):
		if _blight_manager.has_node("ActionTimer"):
			_blight_manager.get_node("ActionTimer").stop()
		if _blight_manager.has_node("SpawnScalerTimer"):
			_blight_manager.get_node("SpawnScalerTimer").stop()
		if _blight_manager.has_node("SpreadScalerTimer"):
			_blight_manager.get_node("SpreadScalerTimer").stop()
	
	# Calculate score
	var resource_score = 0.0
	resource_score += ResourceManager.current_resources.get(&"biomass", 0.0) * biomass_weight
	resource_score += ResourceManager.current_resources.get(&"energy", 0.0) * energy_weight
	resource_score += ResourceManager.current_resources.get(&"nutrients", 0.0) * nutrients_weight
	
	var time_bonus = 1.0 + (_time_survived * time_multiplier)
	var final_score = int(resource_score * time_bonus)
	
	print("Final Score: %d" % final_score)
	game_over.emit(final_score)
