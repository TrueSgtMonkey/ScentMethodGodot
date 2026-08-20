extends Node

var player_ref: CharacterBody3D = null

func _ready():
	randomize()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("quit_game"):
		get_tree().quit()
