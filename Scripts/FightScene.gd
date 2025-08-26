# FightScene.gd - Complete version with enhanced win/lose slide system
extends Node2D
class_name FightScene

# Player references
var player1: BaseCharacter
var player2: BaseCharacter

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
@onready var winner_label = $UI/WinnerLabel
@onready var rematch_button= $"UI/WinnerLabel/Rematch button"
@onready var charselect_button= $"UI/WinnerLabel/Character select button"
@onready var back_to_title_button = $"UI/WinnerLabel/Back to title button"

# NEW: Special/Ultimate prompts
@onready var player1_special_prompt = $UI/Player1SpecialPrompt
@onready var player2_special_prompt = $UI/Player2SpecialPrompt
@onready var player1_ult_prompt = $UI/Player1UltPrompt
@onready var player2_ult_prompt = $UI/Player2UltPrompt

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

# Fight setup
@export_group("Fight Intro Sounds")
@export var intro_lines: Array[AudioStream] = []  # Random intro lines
@export var fight_start_sound: AudioStream  # "FIGHT!" sound

# NEW: Low health announcer sounds
@export_group("Low Health Announcer")
@export var low_health_announcer_sounds: Array[AudioStream] = []

# Fight setup state
var entrance_count_finished: int = 0
var intro_sequence_active: bool = false

# NEW: Store original positions for shake effect
var player1_health_bar_original_pos: Vector2
var player2_health_bar_original_pos: Vector2

# NEW: Low health announcer tracking
var low_health_announced: bool = false

# NEW: Low health pulsing tracking
var player1_low_health_pulsing: bool = false
var player2_low_health_pulsing: bool = false
var pulse_timer: float = 0.0

# NEW: Special/Ultimate meter pulsing tracking
var player1_special_full: bool = false
var player2_special_full: bool = false
var player1_ultimate_full: bool = false
var player2_ultimate_full: bool = false

# Controller navigation for win menu
var win_menu_active := false
var current_win_button_index := 0
var win_buttons := []
var original_win_scales := {}

# Control scheme display
@onready var control_scheme = $"Control scheme"
var control_scheme_active := true

func _ready():
	print("FightScene: Ready function starting")
	
	# Connect to EventBus for entrance events
	EventBus.connect("character_entrance_finished", _on_character_entrance_finished)
	EventBus.connect("both_entrances_finished", _on_both_entrances_finished)
	
	# Setup audio and load data
	setup_audio_players()
	load_character_data()
	
	# Setup the fight scene (creates players)
	setup_fight()
	
	# Hide winner UI at start
	hide_winner_ui()
	
	# Connect button signals
	connect_buttons()
	
	# Setup win menu controller navigation
	setup_win_menu_navigation()
	
	# Store original health bar positions for shake effect
	if player1_health_bar:
		player1_health_bar_original_pos = player1_health_bar.position
	if player2_health_bar:
		player2_health_bar_original_pos = player2_health_bar.position
	
	# NEW: Hide special/ultimate prompts initially
	if player1_special_prompt:
		player1_special_prompt.visible = false
	if player2_special_prompt:
		player2_special_prompt.visible = false
	if player1_ult_prompt:
		player1_ult_prompt.visible = false
	if player2_ult_prompt:
		player2_ult_prompt.visible = false
	
	# Show control scheme at start and hide UI bars
	if control_scheme:
		control_scheme.visible = true
		control_scheme_active = true
		hide_ui_bars()
	
	# IMPORTANT: Don't start entrance sequence until control scheme is dismissed
	print("FightScene: Ready function completed - waiting for control scheme dismissal")

func hide_ui_bars():
	# Hide all UI bars while control scheme is showing
	if player1_health_bar:
		player1_health_bar.visible = false
	if player2_health_bar:
		player2_health_bar.visible = false
	if player1_special_meter:
		player1_special_meter.visible = false
	if player2_special_meter:
		player2_special_meter.visible = false
	if player1_ultimate_meter:
		player1_ultimate_meter.visible = false
	if player2_ultimate_meter:
		player2_ultimate_meter.visible = false
	if player1_combo_label:
		player1_combo_label.visible = false
	if player2_combo_label:
		player2_combo_label.visible = false

func show_ui_bars():
	# Show all UI bars when fight starts
	if player1_health_bar:
		player1_health_bar.visible = true
	if player2_health_bar:
		player2_health_bar.visible = true
	if player1_special_meter:
		player1_special_meter.visible = true
	if player2_special_meter:
		player2_special_meter.visible = true
	if player1_ultimate_meter:
		player1_ultimate_meter.visible = true
	if player2_ultimate_meter:
		player2_ultimate_meter.visible = true
	if player1_combo_label:
		player1_combo_label.visible = true
	if player2_combo_label:
		player2_combo_label.visible = true

func setup_win_menu_navigation():
	# Add buttons to navigation array in order (vertical layout)
	win_buttons = [rematch_button, charselect_button, back_to_title_button]
	
	# Store original scales for hover effect
	for button in win_buttons:
		if button:
			original_win_scales[button] = button.scale
	
	# Set initial selection to first button (rematch)
	current_win_button_index = 0

func _input(event):
	# Handle control scheme dismissal first
	if control_scheme_active:
		if Input.is_action_just_pressed("p1_ultimate") or Input.is_action_just_pressed("p2_ultimate"):
			dismiss_control_scheme()
		return
	
	# Handle win menu navigation when active
	if win_menu_active:
		if Input.is_action_just_pressed("dpad_down"):
			navigate_win_menu_down()
		elif Input.is_action_just_pressed("dpad_up"):
			navigate_win_menu_up()
		elif Input.is_action_just_pressed("p1_ultimate") or  Input.is_action_just_pressed("p2_ultimate"):
			press_current_win_button()

func dismiss_control_scheme():
	print("Control scheme dismissed - starting fight intro sequence")
	if control_scheme:
		control_scheme.visible = false
	control_scheme_active = false
	
	# Show UI bars now that control scheme is dismissed
	show_ui_bars()
	
	# IMPORTANT: Enable character processing now
	if player1:
		player1.set_process_unhandled_input(true)
		player1.set_physics_process(true)  # Re-enable character processing
		player1.set_process(true)  # Re-enable _process
	if player2:
		player2.set_process_unhandled_input(true)
		player2.set_physics_process(true)  # Re-enable character processing (including AI)
		player2.set_process(true)  # Re-enable _process
		# IMPORTANT: Activate AI now (check if it's an AI character)
		if player2.get_script() and player2.get_script().get_path().ends_with("AICharacter.gd"):
			player2.ai_active = true
			print("AI activated after control scheme dismissed")
	
	# NOW start the entrance sequence
	start_fight_intro_sequence()

func navigate_win_menu_down():
	if current_win_button_index < win_buttons.size() - 1:
		current_win_button_index += 1
		update_win_button_selection()

func navigate_win_menu_up():
	if current_win_button_index > 0:
		current_win_button_index -= 1
		update_win_button_selection()

func press_current_win_button():
	if current_win_button_index >= 0 and current_win_button_index < win_buttons.size():
		var button = win_buttons[current_win_button_index]
		if button and not button.disabled:
			button.emit_signal("pressed")

func update_win_button_selection():
	# Reset all buttons to normal scale
	for i in range(win_buttons.size()):
		var button = win_buttons[i]
		if not button:
			continue
			
		var original_scale = original_win_scales[button]
		
		if i == current_win_button_index:
			# Scale up selected button
			button.scale = original_scale * 1.1
		else:
			# Reset to original scale
			button.scale = original_scale

# Add this helper method to hide winner UI:
func hide_winner_ui():
	if winner_label:
		winner_label.visible = false
	if rematch_button:
		rematch_button.visible = false
	if charselect_button:
		charselect_button.visible = false
	if back_to_title_button:
		back_to_title_button.visible = false
	
	# Disable win menu navigation
	win_menu_active = false

func show_winner_ui():
	if winner_label:
		winner_label.visible = true
	if rematch_button:
		rematch_button.visible = true
	if charselect_button:
		charselect_button.visible = true
	if back_to_title_button:
		back_to_title_button.visible = true
	
	# Enable win menu navigation and set initial selection
	win_menu_active = true
	current_win_button_index = 0
	update_win_button_selection()

# Add this helper method to connect buttons:
func connect_buttons():
	if rematch_button and not rematch_button.is_connected("pressed", _on_rematch_button_pressed):
		rematch_button.pressed.connect(_on_rematch_button_pressed)
	
	if charselect_button and not charselect_button.is_connected("pressed", _on_charselect_button_pressed):
		charselect_button.pressed.connect(_on_charselect_button_pressed)
	
	if back_to_title_button and not back_to_title_button.is_connected("pressed", _on_back_to_title_button_pressed):
		back_to_title_button.pressed.connect(_on_back_to_title_button_pressed)

func _process(_delta):
	# Restart fight with R key
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
	
	# IMPORTANT: Don't process anything if control scheme is active
	if control_scheme_active:
		return
		
	# Check for defeat states
	if player1 and player2 and fight_active and not fight_over:
		if player1.current_state == BaseCharacter.CharacterState.DEFEAT:
			end_fight(2)
			
		if player2.current_state == BaseCharacter.CharacterState.DEFEAT:
			end_fight(1)
			
	# Check for new combo milestones
	check_combo_milestones()
	
	# Update low health pulsing
	update_low_health_pulsing(_delta)
	
	# NEW: Update special/ultimate meter pulsing
	update_special_ultimate_pulsing(_delta)

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

# Function called when back to title button is pressed
func _on_back_to_title_button_pressed():
	print("Back to title button pressed!")
	get_tree().change_scene_to_file("res://Scenes/title_screen.tscn")

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
	
	# Get game mode from GameState_Manager
	var game_state_manager = get_node_or_null("/root/GameState_Manager")
	var is_pve_mode = game_state_manager and game_state_manager.game_mode == "PVE"
	
	# Create player 1 (always human)
	player1 = PlayerCharacter.new()
	player1.player_number = 1
	player1.character_data = player1_character
	player1.position = $Positions/Player1Position.position
	# IMPORTANT: Disable input until control scheme is dismissed
	player1.set_process_unhandled_input(false)
	player1.set_physics_process(false)  # Disable all character processing
	player1.set_process(false)  # Also disable _process for good measure
	add_child(player1)
	print("Created Player 1")
	
	# Create player 2 (human or AI based on mode)
	if is_pve_mode:
		var ai_script = load("res://Scripts/AICharacter.gd")
		player2 = ai_script.new()
		# IMPORTANT: Set AI to inactive until control scheme is dismissed
		player2.ai_active = false
		print("Created AI Player 2")
	else:
		player2 = PlayerCharacter.new()
		print("Created Human Player 2")
	
	player2.player_number = 2
	player2.character_data = player2_character
	player2.position = $Positions/Player2Position.position
	# IMPORTANT: Disable all processing until control scheme is dismissed
	player2.set_process_unhandled_input(false)
	player2.set_physics_process(false)  # This will stop AI logic in _physics_process
	player2.set_process(false)  # Also disable _process for good measure
	add_child(player2)
	
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
	
	# Activate the fight
	fight_active = true
	fight_over = false
	print("Fight started")

# ENHANCED END_FIGHT METHOD - Wait for winner's attack to finish before victory
func end_fight(winner_id):
	print("Ending fight, winner: Player " + str(winner_id))
	
	# Prevent multiple calls
	if fight_over:
		return
		
	fight_active = false
	fight_over = true
	
	# Get winner and loser
	var winner = player1 if winner_id == 1 else player2
	var loser = player1 if winner_id == 2 else player2
	
	# Play victory sound
	if victory_sound and announcer_audio:
		announcer_audio.stream = victory_sound
		announcer_audio.play()
	
	# Start loser's defeat immediately
	if loser:
		loser.state_machine.change_state("Defeat")
	
	# Wait for winner's current attack animation to finish before victory
	if winner:
		await wait_for_current_animation_to_finish(winner)
		winner.state_machine.change_state("Victory")
	
	# Show winner message after both animations are set up
	await get_tree().create_timer(1.5).timeout  # Extra time for victory slide/animation
	
	var winner_name = player1_character.character_name if winner_id == 1 else player2_character.character_name
	
	# Show winner label and buttons
	if winner_label:
		winner_label.text = winner_name + " Wins!"
		print("Winner label displayed: " + winner_label.text)
	
	show_winner_ui()
	
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

# NEW HELPER METHOD: Wait for current animation to complete
func wait_for_current_animation_to_finish(character: BaseCharacter):
	# Check if character is in an attack state
	var current_state = character.state_machine.get_current_state_name()
	if current_state in ["LightAttack", "HeavyAttack", "SpecialAttack", "UltimateAttack"]:
		print("Waiting for ", current_state, " animation to finish for player ", character.player_number)
		
		# Wait for the attack state to finish (it will transition to Idle when done)
		while character.state_machine.get_current_state_name() == current_state:
			await get_tree().process_frame
		
		print("Attack animation finished for player ", character.player_number)
	else:
		print("Player ", character.player_number, " not in attack state, proceeding immediately")

# NEW METHOD FOR HANDLING CHARACTER DEFEAT
func on_character_defeated(defeated_character: BaseCharacter):
	print("Character defeated: Player ", defeated_character.player_number)
	
	# Determine winner
	var winner_id = 1 if defeated_character.player_number == 2 else 2
	
	# End the fight
	end_fight(winner_id)

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

# Signal handlers - UPDATED with health bar shake effect and low health announcer
func _on_player1_health_changed(new_health):
	if player1_health_bar:
		var old_health = player1_health_bar.value
		player1_health_bar.value = new_health
		
		# Shake health bar if health decreased (took damage)
		if new_health < old_health:
			shake_health_bar(player1_health_bar, player1_health_bar_original_pos)
		
		# Check for low health announcer (25% of max health)
		check_low_health_announcer(player1, new_health)
		
		# Check for low health pulsing
		update_low_health_pulsing_state(player1, new_health, 1)

func _on_player2_health_changed(new_health):
	if player2_health_bar:
		var old_health = player2_health_bar.value
		player2_health_bar.value = new_health
		
		# Shake health bar if health decreased (took damage)
		if new_health < old_health:
			shake_health_bar(player2_health_bar, player2_health_bar_original_pos)
		
		# Check for low health announcer (25% of max health)
		check_low_health_announcer(player2, new_health)
		
		# Check for low health pulsing
		update_low_health_pulsing_state(player2, new_health, 2)

# NEW: Update special/ultimate meter pulsing
func update_special_ultimate_pulsing(delta: float):
	# Create a sine wave for smooth pulsing (1.5 second cycle for faster pulse)
	var pulse_strength = (sin(pulse_timer * 4.18879) + 1.0) / 2.0  # 0.0 to 1.0
	
	# Calculate pulse color: normal white to bright white
	var meter_pulse_color = Color(1.0 + pulse_strength * 0.5, 1.0 + pulse_strength * 0.5, 1.0 + pulse_strength * 0.5, 1.0)
	
	# Apply pulsing to player 1 special meter
	if player1_special_full and player1_special_meter:
		player1_special_meter.modulate = meter_pulse_color
	elif player1_special_meter:
		player1_special_meter.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Normal white
	
	# Apply pulsing to player 1 ultimate meter
	if player1_ultimate_full and player1_ultimate_meter:
		player1_ultimate_meter.modulate = meter_pulse_color
	elif player1_ultimate_meter:
		player1_ultimate_meter.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Normal white
	
	# Apply pulsing to player 2 special meter
	if player2_special_full and player2_special_meter:
		player2_special_meter.modulate = meter_pulse_color
	elif player2_special_meter:
		player2_special_meter.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Normal white
	
	# Apply pulsing to player 2 ultimate meter
	if player2_ultimate_full and player2_ultimate_meter:
		player2_ultimate_meter.modulate = meter_pulse_color
	elif player2_ultimate_meter:
		player2_ultimate_meter.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Normal white

# NEW: Update special/ultimate prompt visibility
func update_special_prompt_visibility(player_id: int, meter_type: String, is_full: bool):
	# Check if we're in PVE mode and hide AI prompts
	var game_state_manager = get_node_or_null("/root/GameState_Manager")
	var is_pve_mode = game_state_manager and game_state_manager.game_mode == "PVE"
	
	# Don't show prompts for AI (player 2 in PVE mode)
	if is_pve_mode and player_id == 2:
		return
	
	var prompt_node: Control = null
	
	# Get the appropriate prompt node
	if player_id == 1 and meter_type == "special":
		prompt_node = player1_special_prompt
	elif player_id == 1 and meter_type == "ultimate":
		prompt_node = player1_ult_prompt
	elif player_id == 2 and meter_type == "special":
		prompt_node = player2_special_prompt
	elif player_id == 2 and meter_type == "ultimate":
		prompt_node = player2_ult_prompt
	
	if prompt_node:
		prompt_node.visible = is_full
		print("Player ", player_id, " ", meter_type, " prompt visibility: ", is_full)

# NEW: Update low health pulsing state for a player
func update_low_health_pulsing_state(character: BaseCharacter, current_health: int, player_num: int):
	var low_health_threshold = character.character_data.max_health * 0.25
	var is_low_health = current_health <= low_health_threshold
	
	if player_num == 1:
		player1_low_health_pulsing = is_low_health
	else:
		player2_low_health_pulsing = is_low_health

# NEW: Update pulsing effect every frame
func update_low_health_pulsing(delta: float):
	pulse_timer += delta
	
	# Create a sine wave for smooth pulsing (2 second cycle)
	var pulse_strength = (sin(pulse_timer * 3.14159) + 1.0) / 2.0  # 0.0 to 1.0
	
	# Apply pulsing to player 1 health bar
	if player1_low_health_pulsing and player1_health_bar and player1_health_bar is TextureProgressBar:
		var health_pulse_color = Color.WHITE.lerp(Color.RED, pulse_strength * 0.7)  # 70% max intensity
		player1_health_bar.tint_progress = health_pulse_color
	elif player1_health_bar and player1_health_bar is TextureProgressBar:
		# Reset to white when not low health
		player1_health_bar.tint_progress = Color.WHITE
	
	# Apply pulsing to player 2 health bar
	if player2_low_health_pulsing and player2_health_bar and player2_health_bar is TextureProgressBar:
		var health_pulse_color = Color.WHITE.lerp(Color.RED, pulse_strength * 0.7)  # 70% max intensity
		player2_health_bar.tint_progress = health_pulse_color
	elif player2_health_bar and player2_health_bar is TextureProgressBar:
		# Reset to white when not low health
		player2_health_bar.tint_progress = Color.WHITE

# NEW: Check for low health announcer (only triggers once per fight)
func check_low_health_announcer(character: BaseCharacter, current_health: int):
	# Only trigger once per fight for the FIRST character to hit low health
	if low_health_announced or not fight_active:
		return
	
	# Calculate 25% of max health
	var low_health_threshold = character.character_data.max_health * 0.25
	
	# Check if character is below 25% health
	if current_health <= low_health_threshold:
		# Get a random low health sound from the FightScene's announcer sounds
		if low_health_announcer_sounds.size() > 0 and announcer_audio:
			var random_sound = low_health_announcer_sounds[randi() % low_health_announcer_sounds.size()]
			
			# Play the announcer line
			announcer_audio.stream = random_sound
			announcer_audio.play()
			
			# Mark that we've announced low health (prevent future announcements)
			low_health_announced = true
			
			print("Low health announcer triggered for: ", character.character_data.character_name)

# NEW: Health bar shake effect with red tint
func shake_health_bar(health_bar: Control, original_position: Vector2):
	if not health_bar:
		return
	
	# Create a quick shake effect
	var shake_strength = 8.0
	var shake_duration = 0.3
	
	# Move health bar with random offset
	var shake_offset = Vector2(
		randf_range(-shake_strength, shake_strength),
		randf_range(-shake_strength, shake_strength)
	)
	health_bar.position = original_position + shake_offset
	
	# Add red tint to the progress texture (assuming it's a TextureProgressBar)
	if health_bar is TextureProgressBar:
		var original_tint = health_bar.tint_progress
		health_bar.tint_progress = Color.RED
		
		# Create tween for both position and tint
		var tween = create_tween()
		tween.parallel().tween_property(health_bar, "position", original_position, shake_duration)
		tween.parallel().tween_property(health_bar, "tint_progress", original_tint, shake_duration)
		tween.tween_callback(func(): 
			health_bar.position = original_position
			health_bar.tint_progress = original_tint
		)
	else:
		# Fallback for regular Control nodes
		var tween = create_tween()
		tween.tween_property(health_bar, "position", original_position, shake_duration)
		tween.tween_callback(func(): health_bar.position = original_position)

func _on_player1_special_changed(new_value):
	if player1_special_meter:
		player1_special_meter.value = new_value
	
	# NEW: Check if special meter is full
	var is_full = (new_value >= player1_character.special_meter_max)
	if is_full != player1_special_full:
		player1_special_full = is_full
		update_special_prompt_visibility(1, "special", is_full)

func _on_player2_special_changed(new_value):
	if player2_special_meter:
		player2_special_meter.value = new_value
	
	# NEW: Check if special meter is full
	var is_full = (new_value >= player2_character.special_meter_max)
	if is_full != player2_special_full:
		player2_special_full = is_full
		update_special_prompt_visibility(2, "special", is_full)

func _on_player1_ultimate_changed(new_value):
	if player1_ultimate_meter:
		player1_ultimate_meter.value = new_value
	
	# NEW: Check if ultimate meter is full
	var is_full = (new_value >= player1_character.ultimate_meter_max)
	if is_full != player1_ultimate_full:
		player1_ultimate_full = is_full
		update_special_prompt_visibility(1, "ultimate", is_full)

func _on_player2_ultimate_changed(new_value):
	if player2_ultimate_meter:
		player2_ultimate_meter.value = new_value
	
	# NEW: Check if ultimate meter is full
	var is_full = (new_value >= player2_character.ultimate_meter_max)
	if is_full != player2_ultimate_full:
		player2_ultimate_full = is_full
		update_special_prompt_visibility(2, "ultimate", is_full)

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

func play_random_intro_line():
	if intro_lines.size() > 0 and announcer_audio:
		var random_intro = intro_lines[randi() % intro_lines.size()]
		announcer_audio.stream = random_intro
		announcer_audio.play()

func _on_character_entrance_finished(character: BaseCharacter):
	entrance_count_finished += 1
	print("Character ", character.player_number, " entrance finished. Count: ", entrance_count_finished)
	
	if entrance_count_finished >= 2:
		# Both entrance animations are done
		EventBus.emit_signal("both_entrances_finished")

func _on_both_entrances_finished():
	print("Both entrances finished - playing FIGHT sound and starting battle")
	
	# Play "FIGHT!" sound
	if fight_start_sound and announcer_audio:
		announcer_audio.stream = fight_start_sound
		announcer_audio.play()
	# Wait for fight sound to play, then enable controls
	await get_tree().create_timer(1.0).timeout
	
	# Enable fighting
	intro_sequence_active = false
	fight_active = true
	fight_over = false
	
	print("Fight controls enabled!")

func start_fight_intro_sequence():
	print("Starting fight intro sequence")
	intro_sequence_active = true
	entrance_count_finished = 0
	
	# Characters start in entrance state (not controllable)
	if player1:
		player1.state_machine.change_state("Entrance")
	if player2:
		player2.state_machine.change_state("Entrance")
	
	# Play random intro line
	play_random_intro_line()
