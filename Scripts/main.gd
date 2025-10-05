# This script sits on the main root node and is responsible for
# coordinating major scene-level systems, like showing the game over screen.
class_name Main
extends Node2D

@export var game_manager: GameManager
@export var game_over_ui: GameOverUI

func _ready() -> void:
	if not is_instance_valid(game_manager):
		push_error("Main script requires a valid GameManager node.")
		return
	if not is_instance_valid(game_over_ui):
		push_error("Main script requires a valid GameOverUI node.")
		return
	
	# When the GameManager announces the game is over, we tell the UI to show itself.
	game_manager.game_over.connect(game_over_ui.show_game_over)
