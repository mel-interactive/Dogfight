# FightScene.gd - FIXED to work with refactored BaseCharacter
extends Node2D
class_name FightScene

# Player references
var player1: BaseCharacter
var player2: BaseCharacter

# Selected character data
var player1_character: CharacterData
var player2_character: CharacterData


# Variables for falling item system
@export var falling_item_scene: PackedScene  # Assign your FallingItem scene (should be the .tscn file)
@export var min_spawn_interval: float = 3.0
@export var max_spawn_interval: float = 6.0
var spawn_timer: float = 0.0
var next_spawn_time: float = 0.0

# NOTE: falling_item_scene should point to the FallingItem.tscn FILE (not an instance in the scene)
# We instantiate NEW copies of it dynamically during gameplay


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
@onready var camera_effects = $CameraEffects

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
	
	# Initialize spawn timer
	next_spawn_time = randf_range(min_spawn_interval, max_spawn_interval)
	print("FightScene: Next spawn time initialized to: ", next_spawn_time)
	
	# VERIFY falling item scene is assigned
	if falling_item_scene:
		print("FightScene: Falling item scene is assigned: ", falling_item_scene.resource_path)
	else:
		push_warning("FightScene: WARNING - falling_item_scene is NOT assigned in the inspector!")
	
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
	# FIXED: Combo labels start hidden (empty) - they'll show when combo > 1
	if player1_combo_label:
		player1_combo_label.visible = true
		player1_combo_label.text = ""  # Start empty
	if player2_combo_label:
		player2_combo_label.visible = true
		player2_combo_label.text = ""  # Start empty

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
		# ARCADE BUTTON 8 - Also dismisses control scheme
		# KEYBOARD - SPACE, ENTER, or ESC also dismiss
		if Input.is_action_just_pressed("p1_ultimate") or Input.is_action_just_pressed("p2_ultimate") or \
		   Input.is_joy_button_pressed(1, 8) or Input.is_joy_button_pressed(2, 8) or \
		   Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_ESCAPE):
			dismiss_control_scheme()
		return
	
	# Handle win menu navigation when active
	if win_menu_active:
		if Input.is_action_just_pressed("dpad_down"):
			navigate_win_menu_down()
		elif Input.is_action_just_pressed("dpad_up"):
			navigate_win_menu_up()
		# ARCADE BUTTON 8 - Also confirms selection in win menu
		elif Input.is_action_just_pressed("p1_ultimate") or  Input.is_action_just_pressed("p2_ultimate") or \
			 Input.is_joy_button_pressed(1, 8) or Input.is_joy_button_pressed(2, 8):
			press_current_win_button()

func dismiss_control_scheme():
	control_scheme_active = false
	if control_scheme:
		control_scheme.visible = false
	
	# Show UI bars now
	show_ui_bars()
	
	# Start the actual fight intro sequence
	start_fight_intro_sequence()

func navigate_win_menu_down():
	# Reset current button scale
	if win_buttons[current_win_button_index]:
		win_buttons[current_win_button_index].scale = original_win_scales[win_buttons[current_win_button_index]]
	
	# Move to next button
	current_win_button_index = (current_win_button_index + 1) % win_buttons.size()
	
	# Highlight new button
	if win_buttons[current_win_button_index]:
		win_buttons[current_win_button_index].scale = original_win_scales[win_buttons[current_win_button_index]] * 1.1

func navigate_win_menu_up():
	# Reset current button scale
	if win_buttons[current_win_button_index]:
		win_buttons[current_win_button_index].scale = original_win_scales[win_buttons[current_win_button_index]]
	
	# Move to previous button
	current_win_button_index = (current_win_button_index - 1 + win_buttons.size()) % win_buttons.size()
	
	# Highlight new button
	if win_buttons[current_win_button_index]:
		win_buttons[current_win_button_index].scale = original_win_scales[win_buttons[current_win_button_index]] * 1.1

func press_current_win_button():
	var button = win_buttons[current_win_button_index]
	if button:
		button.pressed.emit()

func _process(_delta):
	# ===== KEYBOARD DEBUG CONTROLS =====
	# R - Restart fight
	if Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()
		return
	
	# ESC - Back to character select
	if Input.is_key_pressed(KEY_ESCAPE):
		var gsm = get_node_or_null("/root/GameState_Manager")
		if gsm:
			gsm.return_to_character_select()
		else:
			get_tree().change_scene_to_file("res://Scenes/character_select_screen.tscn")
		return
	
	# T - Back to title
	if Input.is_key_pressed(KEY_T):
		get_tree().change_scene_to_file("res://Scenes/title_screen.tscn")
		return
	
	# Check for defeat states - FIXED: Use state_machine instead of enum
	if player1 and player2 and fight_active and not fight_over:
		# FIXED: Check state machine instead of old enum
		if player1.state_machine.get_current_state_name() == "Defeat":
			end_fight(2)
			
		if player2.state_machine.get_current_state_name() == "Defeat":
			end_fight(1)
			
	# Check for new combo milestones
	check_combo_milestones()
	
	# Update low health pulsing
	update_low_health_pulsing(_delta)
	
	# NEW: Update special/ultimate meter pulsing
	update_special_ultimate_pulsing(_delta)
	
	# FIXED: Handle falling item spawning - pause during specials/ultimates/defeat
	if fight_active and not fight_over and not control_scheme_active:
		# Check if either player is using special, ultimate, or is defeated
		var player1_state = player1.state_machine.get_current_state_name() if player1 else ""
		var player2_state = player2.state_machine.get_current_state_name() if player2 else ""
		var special_or_ultimate_active = (player1_state in ["SpecialAttack", "UltimateAttack", "Defeat"]) or (player2_state in ["SpecialAttack", "UltimateAttack", "Defeat"])
		
		# Despawn any existing falling items if special/ultimate/defeat is active
		if special_or_ultimate_active:
			despawn_all_falling_items()
			# Reset spawn timer so we don't immediately spawn when they finish
			spawn_timer = 0.0
		else:
			# Normal falling item spawn handling
			spawn_timer += _delta
			if spawn_timer >= next_spawn_time:
				spawn_falling_item()
				spawn_timer = 0.0
				next_spawn_time = randf_range(min_spawn_interval, max_spawn_interval)

# NEW: Helper function to despawn all falling items
func despawn_all_falling_items():
	if not camera_effects:
		return
	
	# Find and remove all FallingItem instances
	for child in camera_effects.get_children():
		if child.has_method("initialize"):  # This is our way of identifying FallingItem nodes
			child.queue_free()

func setup_audio_players():
	if announcer_audio and fight_music:
		music_player.stream = fight_music
		music_player.play()

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
	
	# Check game mode to determine if player 2 should be AI or human
	var game_state_manager = get_node_or_null("/root/GameState_Manager")
	var is_pve_mode = game_state_manager and game_state_manager.game_mode == "PVE"
	
	# Create player 1
	var player1_scene_path = "res://Characters/PlayerCharacter.tscn"
	if ResourceLoader.exists(player1_scene_path):
		var player1_scene = load(player1_scene_path)
		player1 = player1_scene.instantiate()
	else:
		player1 = PlayerCharacter.new()
	
	player1.name = "Player1"
	player1.player_number = 1
	player1.character_data = player1_character
	add_child(player1)
	
	# Position player 1
	if has_node("Positions/Player1Position"):
		player1.global_position = $Positions/Player1Position.global_position
	else:
		var viewport_size = get_viewport().get_visible_rect().size
		player1.global_position = Vector2(viewport_size.x * 0.25, viewport_size.y * 0.75)
	
	# Create player 2 - FIXED: Check game mode!
	if is_pve_mode:
		# PVE mode - create AI character
		print("Creating AI character for Player 2 (PVE mode)")
		var player2_scene_path = "res://Characters/AICharacter.tscn"
		if ResourceLoader.exists(player2_scene_path):
			var player2_scene = load(player2_scene_path)
			player2 = player2_scene.instantiate()
		else:
			player2 = AICharacter.new()
	else:
		# PVP mode - create human player character
		print("Creating PlayerCharacter for Player 2 (PVP mode)")
		var player2_scene_path = "res://Characters/PlayerCharacter.tscn"
		if ResourceLoader.exists(player2_scene_path):
			var player2_scene = load(player2_scene_path)
			player2 = player2_scene.instantiate()
		else:
			player2 = PlayerCharacter.new()
	
	player2.name = "Player2"
	player2.player_number = 2
	player2.character_data = player2_character
	add_child(player2)
	
	# Position player 2
	if has_node("Positions/Player2Position"):
		player2.global_position = $Positions/Player2Position.global_position
	else:
		var viewport_size = get_viewport().get_visible_rect().size
		player2.global_position = Vector2(viewport_size.x * 0.75, viewport_size.y * 0.75)
	
	# Set opponents
	player1.opponent = player2
	player2.opponent = player1
	
	# Connect player signals
	player1.connect("health_changed", _on_player1_health_changed)
	player1.connect("special_meter_changed", _on_player1_special_changed)
	player1.connect("ultimate_meter_changed", _on_player1_ultimate_changed)
	player1.connect("combo_changed", _on_player1_combo_changed)
	
	player2.connect("health_changed", _on_player2_health_changed)
	player2.connect("special_meter_changed", _on_player2_special_changed)
	player2.connect("ultimate_meter_changed", _on_player2_ultimate_changed)
	player2.connect("combo_changed", _on_player2_combo_changed)
	
	# Initialize UI
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
	
	print("FightScene: Players created and positioned")

func connect_buttons():
	if rematch_button:
		rematch_button.pressed.connect(_on_rematch_pressed)
	if charselect_button:
		charselect_button.pressed.connect(_on_charselect_pressed)
	if back_to_title_button:
		back_to_title_button.pressed.connect(_on_back_to_title_pressed)

func end_fight(winner_number: int):
	if fight_over:
		return
	
	fight_over = true
	fight_active = false
	
	print("Fight ended! Winner: Player ", winner_number)
	
	# Set winner to victory state and loser to defeat state (if not already)
	if winner_number == 1:
		await wait_for_current_animation_to_finish(player1)
		player1.state_machine.change_state("Victory")
		if player2.state_machine.get_current_state_name() != "Defeat":
			player2.state_machine.change_state("Defeat")
	else:
		await wait_for_current_animation_to_finish(player2)
		player2.state_machine.change_state("Victory")
		if player1.state_machine.get_current_state_name() != "Defeat":
			player1.state_machine.change_state("Defeat")
	
	# Show winner announcement
	await show_winner_announcement(winner_number)

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
		print("Character not in attack state, proceeding immediately")

func show_winner_announcement(winner_number: int):
	if winner_label:
		winner_label.visible = true
		
		# Get the winning character's name
		var winner_character_name = ""
		if winner_number == 1 and player1 and player1.character_data:
			winner_character_name = player1.character_data.character_name
		elif winner_number == 2 and player2 and player2.character_data:
			winner_character_name = player2.character_data.character_name
		
		# Display character name instead of "Player X"
		if winner_character_name != "":
			winner_label.text = winner_character_name.to_upper() + " WINS!"
		else:
			# Fallback if character name not available
			winner_label.text = "PLAYER " + str(winner_number) + " WINS!"
	
	# Show buttons after a delay
	await get_tree().create_timer(1.0).timeout
	
	if rematch_button:
		rematch_button.visible = true
	if charselect_button:
		charselect_button.visible = true
	if back_to_title_button:
		back_to_title_button.visible = true
	
	# Enable win menu navigation
	win_menu_active = true
	if win_buttons[current_win_button_index]:
		win_buttons[current_win_button_index].scale = original_win_scales[win_buttons[current_win_button_index]] * 1.1

func hide_winner_ui():
	if winner_label:
		winner_label.visible = false
	if rematch_button:
		rematch_button.visible = false
	if charselect_button:
		charselect_button.visible = false
	if back_to_title_button:
		back_to_title_button.visible = false

func _on_rematch_pressed():
	get_tree().reload_current_scene()

func _on_charselect_pressed():
	get_tree().change_scene_to_file("res://Scenes/character_select_screen.tscn")

func _on_back_to_title_pressed():
	get_tree().change_scene_to_file("res://Scenes/title_screen.tscn")

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

func on_character_defeated(defeated_character: BaseCharacter):
	print("Character defeated: Player ", defeated_character.player_number)
	
	# Determine winner
	var winner_id = 1 if defeated_character.player_number == 2 else 2
	
	# End the fight
	end_fight(winner_id)

func play_combo_sound(combo: int):
	if combo_sounds.size() == 0 or not sfx_player:
		return
	
	var sound_index = min(combo - 3, combo_sounds.size() - 1)
	if sound_index >= 0:
		sfx_player.stream = combo_sounds[sound_index]
		sfx_player.play()

# NEW: Update UI prompts for special/ultimate availability
func update_special_prompt_visibility(player_num: int, prompt_type: String, is_full: bool):
	var prompt_node: Control = null
	
	if player_num == 1:
		if prompt_type == "special":
			prompt_node = player1_special_prompt
		else:
			prompt_node = player1_ult_prompt
	else:
		if prompt_type == "special":
			prompt_node = player2_special_prompt
		else:
			prompt_node = player2_ult_prompt
	
	if prompt_node:
		prompt_node.visible = is_full

# NEW: Low health pulsing effect for health bars
func update_low_health_pulsing(delta: float):
	pulse_timer += delta
	
	# Check player 1 low health
	if player1 and player1.current_health <= player1.character_data.max_health * 0.25:
		if not player1_low_health_pulsing:
			player1_low_health_pulsing = true
		
		# Pulse effect
		var pulse_alpha = (sin(pulse_timer * 5.0) + 1.0) / 2.0  # Oscillates between 0 and 1
		var pulse_color = Color(1.0, 0.0, 0.0, 0.3 + pulse_alpha * 0.7)  # Red with pulsing alpha
		
		if player1_health_bar and player1_health_bar is TextureProgressBar:
			player1_health_bar.tint_progress = pulse_color
	else:
		if player1_low_health_pulsing:
			player1_low_health_pulsing = false
			if player1_health_bar and player1_health_bar is TextureProgressBar:
				player1_health_bar.tint_progress = Color.WHITE
	
	# Check player 2 low health
	if player2 and player2.current_health <= player2.character_data.max_health * 0.25:
		if not player2_low_health_pulsing:
			player2_low_health_pulsing = true
		
		# Pulse effect
		var pulse_alpha = (sin(pulse_timer * 5.0) + 1.0) / 2.0
		var pulse_color = Color(1.0, 0.0, 0.0, 0.3 + pulse_alpha * 0.7)
		
		if player2_health_bar and player2_health_bar is TextureProgressBar:
			player2_health_bar.tint_progress = pulse_color
	else:
		if player2_low_health_pulsing:
			player2_low_health_pulsing = false
			if player2_health_bar and player2_health_bar is TextureProgressBar:
				player2_health_bar.tint_progress = Color.WHITE

# NEW: Special/Ultimate meter pulsing when full
func update_special_ultimate_pulsing(delta: float):
	var pulse_alpha = (sin(pulse_timer * 3.0) + 1.0) / 2.0
	
	# Player 1 special
	if player1_special_full and player1_special_meter and player1_special_meter is TextureProgressBar:
		var pulse_color = Color(1.0, 1.0, 0.0, 0.5 + pulse_alpha * 0.5)  # Yellow pulse
		player1_special_meter.tint_progress = pulse_color
	
	# Player 1 ultimate
	if player1_ultimate_full and player1_ultimate_meter and player1_ultimate_meter is TextureProgressBar:
		var pulse_color = Color(1.0, 0.0, 1.0, 0.5 + pulse_alpha * 0.5)  # Purple pulse
		player1_ultimate_meter.tint_progress = pulse_color
	
	# Player 2 special
	if player2_special_full and player2_special_meter and player2_special_meter is TextureProgressBar:
		var pulse_color = Color(1.0, 1.0, 0.0, 0.5 + pulse_alpha * 0.5)
		player2_special_meter.tint_progress = pulse_color
	
	# Player 2 ultimate
	if player2_ultimate_full and player2_ultimate_meter and player2_ultimate_meter is TextureProgressBar:
		var pulse_color = Color(1.0, 0.0, 1.0, 0.5 + pulse_alpha * 0.5)
		player2_ultimate_meter.tint_progress = pulse_color

func _on_player1_health_changed(new_health):
	if player1_health_bar:
		player1_health_bar.value = new_health
		
		# NEW: Shake effect when taking damage
		if new_health < player1.current_health:
			shake_health_bar(player1_health_bar, player1_health_bar_original_pos)
	
	# NEW: Low health announcer (play ONCE when health drops below 25%)
	if new_health <= player1_character.max_health * 0.25 and not low_health_announced:
		play_low_health_announcer(player1)

func _on_player2_health_changed(new_health):
	if player2_health_bar:
		player2_health_bar.value = new_health
		
		# NEW: Shake effect when taking damage
		if new_health < player2.current_health:
			shake_health_bar(player2_health_bar, player2_health_bar_original_pos)
	
	# NEW: Low health announcer
	if new_health <= player2_character.max_health * 0.25 and not low_health_announced:
		play_low_health_announcer(player2)

# NEW: Play low health announcer sound once per fight
func play_low_health_announcer(character: BaseCharacter):
	if low_health_announcer_sounds.size() > 0 and announcer_audio and not low_health_announced:
		var random_sound = low_health_announcer_sounds[randi() % low_health_announcer_sounds.size()]
		announcer_audio.stream = random_sound
		announcer_audio.play()
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
	
	
	
	
	# FIXED: spawn_falling_item with better error handling and debugging
# 70% spawn between characters, 30% spawn above a player
# Avoid spawning too close to edges to prevent punishing cornered players
func spawn_falling_item():
	# CRITICAL: Check if falling_item_scene is assigned
	if not falling_item_scene:
		push_error("falling_item_scene is not assigned! Please assign it in the inspector.")
		return
	
	# Check if players exist
	if not player1:
		return
	
	if not player2:
		push_warning("Player2 not initialized yet, skipping spawn")
		return
	
	# Get viewport bounds for safe spawning
	var viewport_size = get_viewport_rect().size
	var safe_margin = 200.0  # Don't spawn within 200px of edges (leaves room for 150px collider + 50px margin)
	var min_x = safe_margin
	var max_x = viewport_size.x - safe_margin
	
	var target_position = Vector2()
	
	# 70% chance to spawn between characters, 30% chance to spawn above a player
	if randf() < 0.7:
		# Spawn between the two characters
		var player1_x = player1.global_position.x
		var player2_x = player2.global_position.x
		
		# Calculate midpoint between players
		var midpoint_x = (player1_x + player2_x) / 2.0
		
		# Add some randomness around the midpoint (±100 pixels for variety)
		target_position.x = midpoint_x + randf_range(-100, 100)
		
		# Clamp to safe boundaries
		target_position.x = clamp(target_position.x, min_x, max_x)
	else:
		# Spawn above a player (30% of the time)
		# SMART TARGETING: Try to hit the player who is NOT cornered
		var player1_x = player1.global_position.x
		var player2_x = player2.global_position.x
		
		# Determine who is closer to the edges (more cornered)
		var player1_distance_to_left = player1_x - min_x
		var player1_distance_to_right = max_x - player1_x
		var player2_distance_to_left = player2_x - min_x
		var player2_distance_to_right = max_x - player2_x
		
		# Find minimum distance to any edge for each player
		var player1_min_edge_distance = min(player1_distance_to_left, player1_distance_to_right)
		var player2_min_edge_distance = min(player2_distance_to_left, player2_distance_to_right)
		
		var target_player: BaseCharacter
		
		# If one player is significantly more cornered, target the OTHER player
		var corner_threshold = 250.0  # Consider "cornered" if within 250px of edge
		if player1_min_edge_distance < corner_threshold and player2_min_edge_distance >= corner_threshold:
			# Player 1 is cornered, target player 2 (the cornering player)
			target_player = player2
		elif player2_min_edge_distance < corner_threshold and player1_min_edge_distance >= corner_threshold:
			# Player 2 is cornered, target player 1 (the cornering player)
			target_player = player1
		else:
			# Neither is cornered or both are cornered, pick randomly
			target_player = player1 if randf() > 0.5 else player2
		
		target_position.x = target_player.global_position.x
		
		# Add some randomness so it's not exactly on the player
		target_position.x += randf_range(-50, 50)
		
		# Clamp to safe boundaries
		target_position.x = clamp(target_position.x, min_x, max_x)
	
	# Set Y position to spawn from top
	target_position.y = 0
	
	var item = falling_item_scene.instantiate()
	if not item:
		push_error("Failed to instantiate falling_item_scene!")
		return
	
	# IMPORTANT: Add to the correct parent node
	# Try camera_effects first, fallback to self
	var parent_node = camera_effects if camera_effects else self
	parent_node.add_child(item)
	
	# Initialize the item
	item.initialize(target_position)
