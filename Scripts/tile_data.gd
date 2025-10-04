# Defines the static properties of a game tile.
# By using a custom Resource, we can create, manage, and balance game content
# entirely within the Godot editor by creating and editing .tres files.
# This decouples game data from game logic, which is crucial for iteration.
class_name Tile_Data
extends Resource

## A unique identifier for this tile type, used for rule lookups.
@export var id: StringName

## The player-facing name of the tile.
@export var display_name: String

## The category this tile belongs to (e.g., "harvester", "generator").
# Used by other tiles' synergy rules to identify this tile.
@export var category: StringName

## The cost to place this tile, keyed by resource type.
# Example: {"biomass": 50.0, "energy": 10.0}
@export var cost: Dictionary # {resource_type: StringName, amount: float}

## The base amount of resources this tile generates per tick, before synergies.
# Example: {"biomass": 1.0}
@export var base_generation: Dictionary # {resource_type: StringName, amount: float}

## The rules defining how this tile's output is modified by its neighbors.
# The keys are the 'category' or 'id' of a neighboring tile.
# The value is a dictionary defining the modification.
# See README.md section 8.3 for examples.
@export var synergy_rules: Dictionary

## The texture used to represent this tile on the grid.
@export var texture: Texture2D

## A player-facing description for UI tooltips.
@export var description: String

## An array of tags for more complex rule-checking or filtering.
@export var tags: Array[StringName] = []

## A flag to identify if this tile has defensive properties (e.g., against Blight).
@export var is_defensive: bool = false
