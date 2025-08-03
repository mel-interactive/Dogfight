extends Node
class_name CharacterManager

# Singleton for managing available characters
# Add this script to Autoload in Project Settings to use as a singleton

# List of available character resources
var available_characters = []

# Base character scene path - update this to match your actual base character scene
@export var base_character_scene_path: String = "res://Scenes/base_character.tscn"
var base_character_scene: PackedScene

# Default character paths - these should be updated to match your actual file paths
var character_paths = [
	
	"res://Character Resources/Dennis.tres",
	"res://Character Resources/Olaf.tres",
	"res://Character Resources/Erwin.tres",
	"res://Character Resources/Josh.tres",
	"res://Character Resources/Louis.tres",
	"res://Character Resources/Michael.tres",
	"res://Character Resources/Teague.tres"
]

func _ready():
	load_base_character_scene()
	load_characters()

func load_base_character_scene():
	if ResourceLoader.exists(base_character_scene_path):
		base_character_scene = ResourceLoader.load(base_character_scene_path)
		if not base_character_scene:
			print("Error: Failed to load base character scene from " + base_character_scene_path)
	else:
		print("Warning: Base character scene not found at " + base_character_scene_path)

func load_characters():
	available_characters.clear()
	
	for path in character_paths:
		if ResourceLoader.exists(path):
			var character = ResourceLoader.load(path)
			if character is CharacterData:
				available_characters.append(character)
		else:
			print("Warning: Character resource not found at " + path)

# Get a character by ID
func get_character_by_id(character_id: String) -> CharacterData:
	for character in available_characters:
		if character.character_id == character_id:
			return character
	return null

# Create a character instance with proper configuration
func create_character_instance(character_data: CharacterData, player_number: int) -> BaseCharacter:
	if not base_character_scene:
		print("Error: Base character scene not loaded!")
		return null
	
	if not character_data:
		print("Error: No character data provided!")
		return null
	
	if player_number < 1 or player_number > 2:
		print("Error: Invalid player number: ", player_number)
		return null
	
	# Create the character instance
	var character_instance = base_character_scene.instantiate() as BaseCharacter
	if not character_instance:
		print("Error: Failed to create character instance!")
		return null
	
	# Configure the character
	character_instance.character_data = character_data
	character_instance.player_number = player_number
	character_instance.name = "Player%d_%s" % [player_number, character_data.character_name]
	
	print("Created character instance: ", character_instance.name, " (Player ", player_number, ")")
	
	return character_instance

# Create both player characters and set up their relationship
func create_player_characters(player1_data: CharacterData, player2_data: CharacterData) -> Array:
	var player1_instance = create_character_instance(player1_data, 1)
	var player2_instance = create_character_instance(player2_data, 2)
	
	if not player1_instance or not player2_instance:
		print("Error: Failed to create one or both character instances!")
		return []
	
	# Set up opponent references
	player1_instance.opponent = player2_instance
	player2_instance.opponent = player1_instance
	
	return [player1_instance, player2_instance]

# Function for GameStateManager to use
func create_characters_for_game_state(gsm: GameStateManager) -> Array:
	if not gsm.player1_character or not gsm.player2_character:
		print("Error: GameStateManager missing character data!")
		return []
	
	return create_player_characters(gsm.player1_character, gsm.player2_character)
