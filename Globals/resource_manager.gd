# Autoload Singleton: Manages the player's resources.
# This is the single source of truth for all currency transactions.
# It ensures that all resource changes are valid and broadcasts updates to the rest of the game.
extends Node

# Emitted whenever the total amount of any resource changes.
# The UI will connect to this to keep the display in sync.
signal resources_updated(current_resources: Dictionary)

# Emitted specifically when resources are generated.
signal resources_generated(delta: Dictionary)

# Emitted specifically when resources are spent.
signal resources_spent(cost: Dictionary)

# The dictionary holding the current amount of each resource the player has.
# Keys are resource StringNames (e.g., &"biomass"), values are floats.
# The dictionary holding the current amount of each resource the player has.
# Keys are resource StringNames (e.g., &"biomass"), values are floats.
var current_resources: Dictionary = {
	&"biomass": 100.0, # Starting with some initial resources for testing.
	&"energy": 25.0,
	&"nutrients": 0.0  
}


# Adds a dictionary of resources to the player's totals.
# To be called by the GameManager at the end of each tick.
func add_resources(delta: Dictionary) -> void:
	if delta.is_empty():
		return
	
	for key in delta:
		current_resources[key] = current_resources.get(key, 0.0) + delta[key]
	
	resources_generated.emit(delta)
	resources_updated.emit(current_resources)


# Checks if the player has enough resources to afford a given cost.
# Returns 'true' if affordable, 'false' otherwise.
func can_afford(cost: Dictionary) -> bool:
	for key in cost:
		if current_resources.get(key, 0.0) < cost[key]:
			return false
	return true


# Attempts to spend resources.
# If the player can afford the cost, it subtracts the resources and returns 'true'.
# Otherwise, it does nothing and returns 'false'.
func spend_resources(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	
	for key in cost:
		current_resources[key] -= cost[key]
	
	resources_spent.emit(cost)
	resources_updated.emit(current_resources)
	return true
