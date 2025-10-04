# Manages the main game UI, primarily the resource display.
# It listens to the ResourceManager and updates the labels accordingly.
# This script acts as a coordinator for the UI layer.
extends Control

# --- Signals ---
# Emitted when a tile is selected from the build panel.
# The PlacementController will connect to this to know what to build.
signal tile_to_build_selected(tile_data: Tile_Data)

# --- Node References ---
# How to use:
# In your main_ui.tscn, ensure you have a Label node named 'ResourceLabel'.
@onready var resource_label: Label = $ResourceLabel
# In your main_ui.tscn, ensure you have a child node for the build panel,
# and that this node has the build_panel.gd script attached.
@onready var build_panel = $BuildPanel


# --- Godot Engine Functions ---

# Called when the node enters the scene tree for the first time.
# This is where we connect to global signals.
func _ready() -> void:
	# --- How to use: ---
	# 1. Attach this script to the root node of Scenes/UI/main_ui.tscn.
	# 2. Add a Label node named "ResourceLabel" as a child.
	# 3. Add a container node named "BuildPanel" as a child and attach build_panel.gd to it.
	
	# Connect to the ResourceManager's signal to know when to update the display.
	ResourceManager.resources_updated.connect(_on_resources_updated)
	
	# Connect to the child build panel's signal. When it emits, this UI will re-emit
	# the signal for other systems to hear (like the PlacementController).
	build_panel.tile_selected.connect(_on_build_panel_tile_selected)
	
	# Initialize the UI with the starting resource values.
	_on_resources_updated(ResourceManager.current_resources)


# --- Signal Handlers ---

## Called every time the ResourceManager reports a change in resource totals.
func _on_resources_updated(current_resources: Dictionary) -> void:
	# We build a string to display the resources. This is a simple implementation.
	# For a more complex UI, you might have separate labels for each resource.
	var text_parts: Array[String]
	for resource_name in current_resources:
		var amount: int = floori(current_resources[resource_name])
		text_parts.append("%s: %d" % [resource_name, amount])
	
	resource_label.text = " | ".join(text_parts)


## Called when a tile button is clicked in the BuildPanel.
func _on_build_panel_tile_selected(tile_data: Tile_Data) -> void:
	# Pass the signal up for the rest of the game to hear.
	tile_to_build_selected.emit(tile_data)
