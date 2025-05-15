extends Node
class_name CharacterManager

# Singleton for managing available characters
# Add this script to Autoload in Project Settings to use as a singleton

# List of available character resources
var available_characters = []

# Default character paths - these should be updated to match your actual file paths
var character_paths = [
	"res://Character Scripts/Dennis.tres",
	"res://Character Scripts/Olaf.tres",
	"res://Character Scripts/Erwin.tres",
	"res://Character Scripts/Josh.tres",
	"res://Character Scripts/Louis.tres",
	"res://Character Scripts/Michael.tres",
	"res://Character Scripts/Rose.tres",
	"res://Character Scripts/Teague.tres"
]

func _ready():
	# Load all character data resources
	load_characters()

func load_characters():
	available_characters.clear()
	
	# Try to load each character
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
