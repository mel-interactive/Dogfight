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

# New function for returning to character select
func return_to_character_select() -> void:
	# Change back to character select screen
	print("Returning to character select screen")
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
