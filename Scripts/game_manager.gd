# Orchestrates the main game loop and coordinates the different manager singletons.
# This node acts as the "heartbeat" of the game, triggering the core logic on a set interval.
extends Node

## The time in seconds between each game tick.
@export var tick_rate: float = 1.0

# A dictionary holding the total resource generation per tick for the entire grid.
# This is updated by the GridManager.
var _total_generation: Dictionary = {}

# --- Node References ---
@onready var tick_timer: Timer = $TickTimer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# How to use:
	# This script should be placed on a "GameManager" node in your main scene.
	# That node must have a child Timer node named "TickTimer".
	# The GridManager must also be a child of the scene so it can be found.
	var grid_manager = get_node("../GridManager") # Adjust path if needed
	if not grid_manager:
		push_error("GameManager could not find GridManager node!")
		return
		
	# Connect to the GridManager's signal to receive updated generation values.
	grid_manager.generation_recalculated.connect(_on_grid_manager_generation_recalculated)
	
	# Connect the timer's timeout signal to the main tick function.
	tick_timer.wait_time = tick_rate
	tick_timer.timeout.connect(_on_tick_timer_timeout)
	tick_timer.start()


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
