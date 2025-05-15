extends Node2D
class_name FightScene

# Player references
var player1: PlayerCharacter
var player2: PlayerCharacter

# Selected character data
var player1_character: CharacterData
var player2_character: CharacterData

# UI elements
@onready var player1_health_bar = $UI/Player1HealthBar
@onready var player2_health_bar = $UI/Player2HealthBar
@onready var player1_special_meter = $UI/Player1SpecialMeter
@onready var player2_special_meter = $UI/Player2SpecialMeter
@onready var player1_ultimate_meter = $UI/Player1UltimateMeter
@onready var player2_ultimate_meter = $UI/Player2UltimateMeter
@onready var player1_combo_label = $UI/Player1ComboLabel
@onready var player2_combo_label = $UI/Player2ComboLabel
@onready var debug_label = $UI/DebugLabel
@onready var winner_label = $UI/WinnerLabel
@onready var rematch_button= $"UI/WinnerLabel/Rematch button"
@onready var charselect_button= $"UI/WinnerLabel/Character select button"

# Audio players
@onready var announcer_audio = $AudioPlayers/AnnouncerAudio
@onready var music_player = $AudioPlayers/MusicPlayer
@onready var sfx_player = $AudioPlayers/SFXPlayer

# Sound effects
@export var round_start_sound: AudioStream
@export var round_end_sound: AudioStream
@export var victory_sound: AudioStream
@export var defeat_sound: AudioStream
@export var combo_sounds: Array[AudioStream] # Different sounds for different combo levels
@export var fight_music: AudioStream

# Gameplay state tracking
var fight_active = false
var max_combo_reached = 0
var highest_combo_player = 0
var fight_over = false  # Track if the fight is over

func _ready():
	print("FightScene: Ready function starting")
	
	# Make sure we have audio players
	setup_audio_players()
	
	# Load the character data
	load_character_data()
	
	# Set up the fight scene
	setup_fight()
	
	# Display debug info
	if debug_label:
		debug_label.text = "Fight started!"
	else:
		print("Debug label not found")
	
	# Hide winner UI at start
	if winner_label:
		winner_label.visible = false
		print("Winner label hidden at start")
	else:
		print("Winner label not found!")
	
	# Connect button signals and hide them
	if rematch_button:
		rematch_button.visible = false
		rematch_button.pressed.connect(_on_rematch_button_pressed)
		print("Rematch button connected and hidden")
	else:
		print("Rematch button not found!")
	
	if charselect_button:
		charselect_button.visible = false
		charselect_button.pressed.connect(_on_charselect_button_pressed)
		print("Character select button connected and hidden")
	else:
		print("Character select button not found!")
	
	# Start the fight sequence
	start_fight_sequence()
	
	print("FightScene: Ready function completed")

func _process(delta):
	# Restart fight with R key
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		
	# Check for defeat states
	if player1 and player2 and fight_active and not fight_over:
		if player1.current_state == BaseCharacter.CharacterState.DEFEAT:
			end_fight(2)
			
		if player2.current_state == BaseCharacter.CharacterState.DEFEAT:
			end_fight(1)
			
	# Check for new combo milestones
	check_combo_milestones()

# Function called when rematch button is pressed
func _on_rematch_button_pressed():
	print("Rematch button pressed!")
	get_tree().reload_current_scene()

# Function called when character select button is pressed
func _on_charselect_button_pressed():
	print("Character select button pressed!")
	
	var game_state_manager = get_node_or_null("/root/GameState_Manager")
	if game_state_manager:
		game_state_manager.return_to_character_select()
	else:
		get_tree().change_scene_to_file("res://Scenes/character_select_screen.tscn")

func setup_audio_players():
	print("Setting up audio players")
	
	# Create audio players if they don't exist
	if not has_node("AudioPlayers"):
		var audio_players = Node.new()
		audio_players.name = "AudioPlayers"
		add_child(audio_players)
		
		# Announcer audio (for "FIGHT!", "KO!", etc.)
		var announcer = AudioStreamPlayer.new()
		announcer.name = "AnnouncerAudio"
		announcer.bus = "Announcer" # You can set up a separate audio bus for this
		announcer.volume_db = 2.0 # Slightly louder than other sounds
		audio_players.add_child(announcer)
		
		# Music player
		var music = AudioStreamPlayer.new()
		music.name = "MusicPlayer"
		music.bus = "Music"
		music.volume_db = -5.0 # Lower volume for background music
		audio_players.add_child(music)
		
		# SFX player for UI and general sounds
		var sfx = AudioStreamPlayer.new()
		sfx.name = "SFXPlayer"
		sfx.bus = "SFX"
		sfx.volume_db = 0.0
		audio_players.add_child(sfx)
		
	# Assign references
	if has_node("AudioPlayers/AnnouncerAudio"):
		announcer_audio = $AudioPlayers/AnnouncerAudio
	if has_node("AudioPlayers/MusicPlayer"):
		music_player = $AudioPlayers/MusicPlayer
	if has_node("AudioPlayers/SFXPlayer"):
		sfx_player = $AudioPlayers/SFXPlayer

func load_character_data():
	print("Loading character data")
	
	# First try to get characters from GameState_Manager
	var game_state_manager = get_node_or_null("/root/GameState_Manager")
	
	if game_state_manager and game_state_manager.player1_character and game_state_manager.player2_character:
		player1_character = game_state_manager.player1_character
		player2_character = game_state_manager.player2_character
		print("Successfully loaded characters from GameState_Manager")
		print("Player 1: " + player1_character.character_name)
		print("Player 2: " + player2_character.character_name)
	else:
		print("Failed to load characters from GameState_Manager")
		
		# Fallback to Character_Manager if available
		var character_manager = get_node_or_null("/root/Character_Manager")
		
		if character_manager:
			# Check if we have characters available
			if character_manager.available_characters.size() >= 2:
				# Use the first character for player 1
				player1_character = character_manager.available_characters[0]
				
				# Use the second character for player 2
				player2_character = character_manager.available_characters[1]
				
				print("Loaded characters from Character_Manager")
				print("Player 1: " + player1_character.character_name)
				print("Player 2: " + player2_character.character_name)
			else:
				print("Character_Manager has insufficient characters, using defaults")
				create_default_characters()
		else:
			print("Character_Manager not found, using defaults")
			create_default_characters()

func create_default_characters():
	print("Creating default characters")
	
	# Create basic defaults as fallback
	player1_character = CharacterData.new()
	player1_character.character_name = "Player 1"
	player1_character.color = Color.BLUE
	player1_character.max_health = 100
	player1_character.light_attack_damage = 5
	player1_character.heavy_attack_damage = 15
	player1_character.special_attack_damage = 25
	player1_character.ultimate_attack_damage = 40
	player1_character.special_meter_max = 100
	player1_character.ultimate_meter_max = 100
	
	player2_character = CharacterData.new()
	player2_character.character_name = "Player 2"
	player2_character.color = Color.RED
	player2_character.max_health = 100
	player2_character.light_attack_damage = 5
	player2_character.heavy_attack_damage = 15
	player2_character.special_attack_damage = 25
	player2_character.ultimate_attack_damage = 40
	player2_character.special_meter_max = 100
	player2_character.ultimate_meter_max = 100
	
	print("Default characters created")

func setup_fight():
	print("Setting up fight scene")
	
	# Verify we have positions for players
	if not has_node("Positions/Player1Position") or not has_node("Positions/Player2Position"):
		push_error("Player position nodes not found!")
		return
	
	# Create player 1
	player1 = PlayerCharacter.new()
	player1.player_id = 1
	player1.character_data = player1_character
	player1.position = $Positions/Player1Position.position
	add_child(player1)
	print("Created Player 1")
	
	# Create player 2
	player2 = PlayerCharacter.new()
	player2.player_id = 2
	player2.character_data = player2_character
	player2.position = $Positions/Player2Position.position
	add_child(player2)
	print("Created Player 2")
	
	# Connect players to each other
	player1.opponent = player2
	player2.opponent = player1
	
	# Connect signals - using safe connection with is_connected check
	if player1.has_signal("health_changed") and not player1.is_connected("health_changed", _on_player1_health_changed):
		player1.connect("health_changed", _on_player1_health_changed)
	
	if player2.has_signal("health_changed") and not player2.is_connected("health_changed", _on_player2_health_changed):
		player2.connect("health_changed", _on_player2_health_changed)
	
	if player1.has_signal("special_meter_changed") and not player1.is_connected("special_meter_changed", _on_player1_special_changed):
		player1.connect("special_meter_changed", _on_player1_special_changed)
	
	if player2.has_signal("special_meter_changed") and not player2.is_connected("special_meter_changed", _on_player2_special_changed):
		player2.connect("special_meter_changed", _on_player2_special_changed)
	
	if player1.has_signal("ultimate_meter_changed") and not player1.is_connected("ultimate_meter_changed", _on_player1_ultimate_changed):
		player1.connect("ultimate_meter_changed", _on_player1_ultimate_changed)
	
	if player2.has_signal("ultimate_meter_changed") and not player2.is_connected("ultimate_meter_changed", _on_player2_ultimate_changed):
		player2.connect("ultimate_meter_changed", _on_player2_ultimate_changed)
	
	if player1.has_signal("combo_changed") and not player1.is_connected("combo_changed", _on_player1_combo_changed):
		player1.connect("combo_changed", _on_player1_combo_changed)
	
	if player2.has_signal("combo_changed") and not player2.is_connected("combo_changed", _on_player2_combo_changed):
		player2.connect("combo_changed", _on_player2_combo_changed)
	
	# Initialize UI with character data if UI elements exist
	if player1_health_bar:
		player1_health_bar.max_value = player1_character.max_health
		player1_health_bar.value = player1_character.max_health
	
	if player2_health_bar:
		player2_health_bar.max_value = player2_character.max_health
		player2_health_bar.value = player2_character.max_health
	
	if player1_special_meter:
		player1_special_meter.max_value = player1_character.special_meter_max
		player1_special_meter.value = 0
	
	if player2_special_meter:
		player2_special_meter.max_value = player2_character.special_meter_max
		player2_special_meter.value = 0
	
	if player1_ultimate_meter:
		player1_ultimate_meter.max_value = player1_character.ultimate_meter_max
		player1_ultimate_meter.value = 0
	
	if player2_ultimate_meter:
		player2_ultimate_meter.max_value = player2_character.ultimate_meter_max
		player2_ultimate_meter.value = 0
	
	if player1_combo_label:
		player1_combo_label.text = ""
	
	if player2_combo_label:
		player2_combo_label.text = ""
	
	# Show character names in the UI (optional)
	if has_node("UI/Player1Name"):
		$UI/Player1Name.text = player1_character.character_name
	
	if has_node("UI/Player2Name"):
		$UI/Player2Name.text = player2_character.character_name
	
	print("Fight setup complete")

func start_fight_sequence():
	print("Starting fight sequence")
	
	# Show "READY" text
	if has_node("UI/ReadyLabel"):
		$UI/ReadyLabel.visible = true
	
	# Play start sound
	if round_start_sound and announcer_audio:
		announcer_audio.stream = round_start_sound
		announcer_audio.play()
	
	# Wait a moment
	await get_tree().create_timer(1.5).timeout
	
	# Show "FIGHT!" text
	if has_node("UI/ReadyLabel"):
		$UI/ReadyLabel.visible = false
	if has_node("UI/FightLabel"):
		$UI/FightLabel.visible = true
		await get_tree().create_timer(1.0).timeout
		$UI/FightLabel.visible = false
	
	# Start background music
	if fight_music and music_player:
		music_player.stream = fight_music
		music_player.play()
	
	# Activate the fight
	fight_active = true
	fight_over = false
	print("Fight started")

func end_fight(winner_id):
	print("Ending fight, winner: Player " + str(winner_id))
	
	# Prevent multiple calls
	if fight_over:
		return
		
	fight_active = false
	fight_over = true
	
	# Stop background music
	if music_player:
		music_player.stop()
	
	# Play victory sound
	if victory_sound and announcer_audio:
		announcer_audio.stream = victory_sound
		announcer_audio.play()
	
	# Show winner message with delay
	await get_tree().create_timer(0.5).timeout
	
	var winner_name = player1_character.character_name if winner_id == 1 else player2_character.character_name
	
	# Show winner label and buttons
	if winner_label:
		winner_label.text = winner_name + " Wins!"
		winner_label.visible = true
		print("Winner label displayed: " + winner_label.text)
		
		# Make sure the buttons are visible too
		if rematch_button:
			rematch_button.visible = true
			print("Rematch button made visible")
		
		if charselect_button:
			charselect_button.visible = true
			print("Character select button made visible")
	else:
		print("ERROR: Winner label not found when trying to show it!")
	
	# Show "K.O." label if it exists
	if has_node("UI/KOLabel"):
		$UI/KOLabel.visible = true
	
	# Notify the GameState_Manager
	var game_state_manager = get_node_or_null("/root/GameState_Manager")
	if game_state_manager:
		print("GameState_Manager found, updating winner info")
		game_state_manager.current_winner = winner_id
	else:
		print("GameState_Manager not found, staying in fight scene")
		
	# Play end round sound
	if round_end_sound and sfx_player:
		await get_tree().create_timer(1.0).timeout
		sfx_player.stream = round_end_sound
		sfx_player.play()
	
	# Show restart message
	if debug_label:
		debug_label.text = "Game Over - Use buttons to continue"

func check_combo_milestones():
	# Check player 1 combo
	if player1 and player1.combo_count > max_combo_reached:
		max_combo_reached = player1.combo_count
		highest_combo_player = 1
		play_combo_sound(max_combo_reached)
	
	# Check player 2 combo
	if player2 and player2.combo_count > max_combo_reached:
		max_combo_reached = player2.combo_count
		highest_combo_player = 2
		play_combo_sound(max_combo_reached)

func play_combo_sound(combo_count):
	if combo_sounds and combo_sounds.size() > 0 and sfx_player:
		# Only play sounds for combos of 3 or higher
		if combo_count >= 3:
			# Calculate which sound to use
			var sound_index = min(combo_count - 3, combo_sounds.size() - 1)
			
			# Play the appropriate combo sound
			sfx_player.stream = combo_sounds[sound_index]
			sfx_player.play()
			
			# Flash the combo text for visual feedback
			flash_combo_text(highest_combo_player)

func flash_combo_text(player_id):
	var combo_label = player1_combo_label if player_id == 1 else player2_combo_label
	
	if not combo_label:
		return
	
	# Store original color
	var original_color = combo_label.get_theme_color("font_color", "Label")
	
	# Flash effect using a tween
	var tween = create_tween()
	tween.tween_property(combo_label, "modulate", Color(1, 1, 0, 1), 0.1)
	tween.tween_property(combo_label, "modulate", Color(1, 0, 0, 1), 0.1)
	tween.tween_property(combo_label, "modulate", Color(1, 1, 0, 1), 0.1)
	tween.tween_property(combo_label, "modulate", Color(1, 1, 1, 1), 0.1)

# Signal handlers
func _on_player1_health_changed(new_health):
	if player1_health_bar:
		player1_health_bar.value = new_health

func _on_player2_health_changed(new_health):
	if player2_health_bar:
		player2_health_bar.value = new_health

func _on_player1_special_changed(new_value):
	if player1_special_meter:
		player1_special_meter.value = new_value

func _on_player2_special_changed(new_value):
	if player2_special_meter:
		player2_special_meter.value = new_value

func _on_player1_ultimate_changed(new_value):
	if player1_ultimate_meter:
		player1_ultimate_meter.value = new_value

func _on_player2_ultimate_changed(new_value):
	if player2_ultimate_meter:
		player2_ultimate_meter.value = new_value

func _on_player1_combo_changed(new_combo):
	if player1_combo_label:
		if new_combo > 1:
			player1_combo_label.text = str(new_combo) + " HIT COMBO!"
		else:
			player1_combo_label.text = ""

func _on_player2_combo_changed(new_combo):
	if player2_combo_label:
		if new_combo > 1:
			player2_combo_label.text = str(new_combo) + " HIT COMBO!"
		else:
			player2_combo_label.text = ""
