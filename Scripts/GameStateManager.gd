extends Node
class_name GameStateManager

# Scene paths
const CHARACTER_SELECT_SCENE = "res://Scenes/character_select_screen.tscn"
const FIGHT_SCENE = "res://Scenes/fight_scene.tscn"

# Character data for the players
var player1_character: CharacterData = null
var player2_character: CharacterData = null

# Game state tracking
var current_winner: int = 0
var player1_wins: int = 0
var player2_wins: int = 0

# Store references to the actual character instances during fights
var player1_instance: BaseCharacter = null
var player2_instance: BaseCharacter = null

func _ready():
	# Initialize game state
	pass

# Called by CharacterSelectScreen when both players are ready
func start_fight() -> void:
	# This will be called when both players have selected characters and pressed ready
	print("GameState_Manager: Starting fight with characters:", 
		player1_character.character_name if player1_character else "None",
		player2_character.character_name if player2_character else "None")
	get_tree().change_scene_to_file(FIGHT_SCENE)

# Called by FightScene when it's ready to set up characters
func setup_fight_characters(fight_scene_node: Node) -> void:
	if not player1_character or not player2_character:
		print("Error: Missing character data!")
		return
	
	# Get characters from CharacterManager
	var character_manager = get_node_or_null("/root/Character_Manager")
	if not character_manager:
		print("Error: Character_Manager not found!")
		return
	
	var characters = character_manager.create_characters_for_game_state(self)
	if characters.size() != 2:
		print("Error: Failed to create characters!")
		return
	
	player1_instance = characters[0]
	player2_instance = characters[1]
	
	# Add characters to fight scene
	fight_scene_node.add_child(player1_instance)
	fight_scene_node.add_child(player2_instance)
	
	# Position them (adjust these positions as needed for your fight scene)
	player1_instance.global_position = Vector2(200, 360)  # Left side
	player2_instance.global_position = Vector2(600, 360)  # Right side
	
	print("Characters set up successfully!")

# Helper function for the fight scene to get character instances
func create_player_characters() -> Array:
	var character_manager = get_node_or_null("/root/Character_Manager")
	if not character_manager:
		print("Error: Character_Manager not found!")
		return []
	
	return character_manager.create_characters_for_game_state(self)

# Function to get the player number for a specific character (for auto-detection)
func get_player_number_for_character(character_instance: BaseCharacter) -> int:
	if character_instance == player1_instance:
		return 1
	elif character_instance == player2_instance:
		return 2
	
	# Fallback: check character data
	if character_instance.character_data == player1_character:
		return 1
	elif character_instance.character_data == player2_character:
		return 2
	
	# Default fallback
	return 1

# Called by FightScene when a player wins
func fight_completed(winner_id: int) -> void:
	# Track the winner
	current_winner = winner_id
	
	# Update win counters
	if winner_id == 1:
		player1_wins += 1
	elif winner_id == 2:
		player2_wins += 1
	
	print("Fight completed. Player " + str(winner_id) + " won.")
	
	# Clear character instances
	player1_instance = null
	player2_instance = null

# New function for returning to character select
func return_to_character_select() -> void:
	# Clear character instances
	player1_instance = null
	player2_instance = null
	
	# Change back to character select screen
	print("Returning to character select screen")
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)

# Function to get character data for the fight scene
func get_player1_character() -> CharacterData:
	return player1_character

func get_player2_character() -> CharacterData:
	return player2_character
