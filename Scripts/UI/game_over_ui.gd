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

# --- GODOT ENGINE FUNCTIONS ---
func _ready() -> void:
	self.visible = false


# --- Public Functions ---
func show_game_over(score: int) -> void:
	_final_score = score
	score_label.text = "Final Score: %d" % _final_score
	self.visible = true
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
	
	submit_button.text = "Submitted!"
	score_submitted.emit()
