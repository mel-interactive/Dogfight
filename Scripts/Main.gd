extends Node2D

func _ready():
	# Make sure the GameStateManager is available globally
	if not get_node_or_null("/root/GameState_Manager"):
		var game_state_manager = load("res://Scripts/GameStateManager.gd").new()
		game_state_manager.name = "GameStateManager"
		get_tree().root.add_child(game_state_manager)
	
	# Start with the character selection screen
	get_tree().change_scene_to_file("res://Scenes/character_select_screen.tscn")
