# Manages the game over screen, score display, and leaderboard submission.
class_name GameOverUI
extends Control

# --- Signals ---
signal score_submitted

# --- Node References ---
@onready var score_label: Label = $PanelContainer/VBoxContainer/ScoreLabel
@onready var name_input: LineEdit = $PanelContainer/VBoxContainer/NameInput
@onready var submit_button: Button = $PanelContainer/VBoxContainer/SubmitButton

# --- Properties ---
var _final_score: int = 0
var _simpleboards_api: Node # We will get this from the main scene

# --- GODOT ENGINE FUNCTIONS ---
func _ready() -> void:
	# --- How to use: ---
	# 1. Attach this script to the root of your game_over_ui.tscn scene.
	# 2. Ensure the node paths in @onready vars are correct for your scene structure.
	
	# The UI is hidden by default.
	hide()
	
	# Find the SimpleBoardsApi node.
	_simpleboards_api = get_node("/root/Main/SimpleBoardsApi")
	if not is_instance_valid(_simpleboards_api):
		push_error("GameOverUI could not find SimpleBoardsApi node!")
		submit_button.disabled = true

	submit_button.pressed.connect(_on_submit_button_pressed)


# --- Public Functions ---
func show_game_over(score: int) -> void:
	_final_score = score
	score_label.text = "Final Score: %d" % _final_score
	show()
	name_input.grab_focus()

# --- Signal Handlers ---
func _on_submit_button_pressed() -> void:
	submit_button.disabled = true
	submit_button.text = "Submitting..."
	
	var player_name = name_input.text
	if player_name.is_empty():
		player_name = "Player"
		
	var user_login = "TakaVII" # As requested
	var current_utc_time = Time.get_datetime_string_from_system(true)
	
	# We can store extra info in the metadata string
	var metadata_dict = {
		"user": user_login,
		"timestamp_utc": current_utc_time,
		"time_survived": get_node("/root/Main/GameManager")._time_survived
	}
	var metadata_json = JSON.stringify(metadata_dict)
	
	print("Submitting score for %s: %d" % [player_name, _final_score])
	
	# Assuming your leaderboard and API key are set up on the SimpleBoardsApi node
	await _simpleboards_api.send_score_without_id(
		"your_leaderboard_id", # IMPORTANT: Replace with your actual leaderboard ID
		player_name,
		str(_final_score),
		metadata_json
	)
	
	submit_button.text = "Submitted!"
	score_submitted.emit()
