extends Node2D
class_name CharacterSelectScreen

# === Nodes ===
@onready var player1_grid = $Player1Side/CharacterGrid
@onready var player2_grid = $Player2Side/CharacterGrid
@onready var player1_ready_button = $Player1Side/ReadyButton
@onready var player2_ready_button = $Player2Side/ReadyButton

@onready var navigation_sound = $AudioPlayers/NavigationSound
@onready var select_sound = $AudioPlayers/SelectSound
@onready var ready_sound = $AudioPlayers/ReadySound
@onready var start_sound = $AudioPlayers/StartSound
@onready var music_player = $AudioPlayers/MusicPlayer

# === Audio Streams (Inspector Settable) ===
@export var navigation_audio: AudioStream
@export var select_audio: AudioStream
@export var ready_audio: AudioStream
@export var start_audio: AudioStream
@export var background_music: AudioStream

# === State ===
var available_characters: Array = []

var player1_selected_index := -1
var player2_selected_index := -1
var player1_hovered_index := 0
var player2_hovered_index := 0
var player1_ready := false
var player2_ready := false

var player1_character: CharacterData = null
var player2_character: CharacterData = null

var player1_boxes := []
var player2_boxes := []

# NEW: AI variables
var is_pve_mode: bool = false
var ai_selection_timer: float = 0.0
var ai_ready_timer: float = 0.0
var ai_selection_phase: String = "hovering"  # "hovering", "selecting", "ready"

func _ready():
	# Check if we're in PVE mode
	var gsm = get_node_or_null("/root/GameState_Manager")
	is_pve_mode = gsm and gsm.game_mode == "PVE"
	
	setup_audio()
	load_characters()

	setup_character_grid(player1_grid, 1)
	setup_character_grid(player2_grid, 2)

	# Wait for character boxes to be fully set up before setting initial hover
	await get_tree().process_frame
	await get_tree().process_frame

	if available_characters.size() > 0:
		update_hover(1, 0)
		update_hover(2, 0)

	player1_ready_button.pressed.connect(_on_player1_ready)
	
	if not is_pve_mode:
		player2_ready_button.pressed.connect(_on_player2_ready)
		player2_ready_button.text = "SELECT FIRST"
	else:
		# In PVE mode, hide player 2 ready button or make it non-interactive
		player2_ready_button.text = "AI WAITING..."
		player2_ready_button.disabled = true

	player1_ready_button.disabled = true
	player2_ready_button.disabled = true
	
	# Set initial button text
	player1_ready_button.text = "SELECT FIRST"

func _process(delta):
	handle_input(1)
	
	if not is_pve_mode:
		handle_input(2)
	else:
		handle_ai_selection(delta)

	if player1_ready and player2_ready:
		start_match()

func handle_ai_selection(delta):
	ai_selection_timer += delta
	
	match ai_selection_phase:
		"hovering":
			# AI only starts hovering AFTER player 1 has pressed READY
			if not player1_ready:
				# Player hasn't pressed ready yet - AI waits patiently
				ai_selection_timer = 0.0  # Reset timer while waiting
				return
			
			# Player has pressed ready, now AI can start moving around
			if ai_selection_timer > randf_range(1.0, 3.0):
				# Occasionally move to different characters (but avoid player's selection)
				if randf() < 0.3:  # 30% chance to move
					var available_indices = get_available_character_indices_for_ai()
					if available_indices.size() > 0:
						var new_index = available_indices[randi() % available_indices.size()]
						if new_index != player2_hovered_index:
							player2_hovered_index = new_index
							update_hover(2, new_index)
							navigation_sound.play()
				
				# Maybe select after hovering enough
				if ai_selection_timer > 2.0 and randf() < 0.4:
					# Make sure we're not hovering over player 1's character
					var available_indices = get_available_character_indices_for_ai()
					if available_indices.has(player2_hovered_index):
						select_character(2, player2_hovered_index)
						ai_selection_phase = "selecting"
						ai_selection_timer = 0.0
					else:
						# Move to a different character if current one is taken
						if available_indices.size() > 0:
							player2_hovered_index = available_indices[randi() % available_indices.size()]
							update_hover(2, player2_hovered_index)
		
		"selecting":
			# AI takes 1-2 seconds to decide if they like this character
			if ai_selection_timer > randf_range(1.0, 2.0):
				# Check if this character is still available (player might have changed their mind)
				var available_indices = get_available_character_indices_for_ai()
				if available_indices.has(player2_selected_index):
					# Character still available, confirm selection
					_on_player2_ready()
					ai_selection_phase = "ready"
				else:
					# Character no longer available, go back to hovering
					unselect_character(2)
					ai_selection_phase = "hovering"
					ai_selection_timer = 0.0

# NEW: Update character availability in both grids
func update_character_availability():
	# Update Player 1's grid - dim characters selected by Player 2
	for i in range(player1_boxes.size()):
		var box = player1_boxes[i]
		var is_taken_by_opponent = (i == player2_selected_index)
		box.set_unavailable(is_taken_by_opponent)
	
	# Update Player 2's grid - dim characters selected by Player 1
	for i in range(player2_boxes.size()):
		var box = player2_boxes[i]
		var is_taken_by_opponent = (i == player1_selected_index)
		box.set_unavailable(is_taken_by_opponent)

# NEW: Get list of character indices that AI can select (not taken by player 1)
func get_available_character_indices_for_ai() -> Array:
	var available_indices = []
	for i in range(available_characters.size()):
		if i != player1_selected_index:  # Don't allow mirror picks
			available_indices.append(i)
	return available_indices

func setup_audio():
	navigation_sound.stream = navigation_audio
	select_sound.stream = select_audio
	ready_sound.stream = ready_audio
	start_sound.stream = start_audio

func load_characters():
	var manager = get_node_or_null("/root/Character_Manager")
	if manager:
		available_characters = manager.available_characters.duplicate(true)

func setup_character_grid(grid: Control, player_id: int):
	if not grid or available_characters.is_empty():
		return

	# Clear existing boxes
	for child in grid.get_children():
		child.queue_free()

	grid.columns = 3
	
	# INCREASED SPACING - change these values to adjust spacing
	grid.add_theme_constant_override("hseparation", 25)  # Horizontal spacing (was 10)
	grid.add_theme_constant_override("vseparation", 25)  # Vertical spacing (was 10)

	var boxes = []
	for character in available_characters:
		var box = preload("res://Scenes/character_box.tscn").instantiate()
		box.custom_minimum_size = Vector2(100, 100)

		# SAFER: defer the call to make sure the node is ready
		box.call_deferred("set_character", character)

		grid.add_child(box)
		boxes.append(box)

	if player_id == 1:
		player1_boxes = boxes
	else:
		player2_boxes = boxes

func handle_input(player_id: int):
	if (player_id == 1 and player1_ready) or (player_id == 2 and player2_ready):
		return

	var prefix = "p%d_" % player_id
	var columns = 3
	var total = available_characters.size()

	var current = player1_hovered_index if player_id == 1 else player2_hovered_index
	var selected = player1_selected_index if player_id == 1 else player2_selected_index

	# NEW: Check for back to title input when nothing is selected
	if selected == -1 and Input.is_action_just_pressed(prefix + "special"):
		go_back_to_title()
		return

	if selected != -1:
		# Changed to use existing ultimate input for unselect (X button)
		if Input.is_action_just_pressed(prefix + "special"):
			unselect_character(player_id)
		# Use existing heavy input for ready up (Triangle button)
		elif Input.is_action_just_pressed(prefix + "heavy"):
			if player_id == 1:
				_on_player1_ready()
			elif player_id == 2:
				_on_player2_ready()
		return

	var new_index = current
	
	# Movement with skipping unavailable characters
	if Input.is_action_just_pressed(prefix + "left"):
		new_index = get_next_available_index(player_id, current, "left", columns, total)
	elif Input.is_action_just_pressed(prefix + "right"):
		new_index = get_next_available_index(player_id, current, "right", columns, total)
	elif Input.is_action_just_pressed(prefix + "light"):
		new_index = get_next_available_index(player_id, current, "up", columns, total)
	elif Input.is_action_just_pressed(prefix + "heavy"):
		new_index = get_next_available_index(player_id, current, "down", columns, total)
	# Use existing special input for character selection (Circle button)
	elif Input.is_action_just_pressed(prefix + "ultimate"):
		# Only allow selection if character is available
		if is_character_available_for_player(player_id, current):
			select_character(player_id, current)

	if new_index != current:
		if player_id == 1:
			player1_hovered_index = new_index
		else:
			player2_hovered_index = new_index
		update_hover(player_id, new_index)
		navigation_sound.play()

# NEW: Function to go back to title screen
func go_back_to_title():
	set_process(false)
	if music_player:
		music_player.stop()
	get_tree().change_scene_to_file("res://Scenes/title_screen.tscn")

# NEW: Get next available character index, skipping unavailable ones
func get_next_available_index(player_id: int, current_index: int, direction: String, columns: int, total: int) -> int:
	var new_index = current_index
	var attempts = 0
	var max_attempts = total  # Prevent infinite loops
	
	while attempts < max_attempts:
		# Calculate next position based on direction
		match direction:
			"left":
				if new_index % columns > 0:
					new_index -= 1
				else:
					break  # Can't go further left
			"right":
				if new_index % columns < columns - 1 and new_index + 1 < total:
					new_index += 1
				else:
					break  # Can't go further right
			"up":
				if new_index - columns >= 0:
					new_index -= columns
				else:
					break  # Can't go further up
			"down":
				if new_index + columns < total:
					new_index += columns
				else:
					break  # Can't go further down
		
		# Check if this character is available for this player
		if is_character_available_for_player(player_id, new_index):
			return new_index  # Found an available character
		
		attempts += 1
	
	# If no available character found in that direction, stay at current position
	return current_index

# NEW: Check if a character is available for a specific player
func is_character_available_for_player(player_id: int, character_index: int) -> bool:
	if character_index < 0 or character_index >= available_characters.size():
		return false
	
	# Character is unavailable if the opponent has selected it
	if player_id == 1:
		return character_index != player2_selected_index
	else:
		return character_index != player1_selected_index

func update_hover(player_id: int, index: int):
	var boxes = player1_boxes if player_id == 1 else player2_boxes
	if index < 0 or index >= boxes.size():
		return

	for i in range(boxes.size()):
		var should_be_hovered = (i == index)
		var box = boxes[i]
		
		# Only call set_hovered if the state is actually changing
		if box.is_hovered != should_be_hovered:
			box.set_hovered(should_be_hovered)

func select_character(player_id: int, index: int):
	if index < 0 or index >= available_characters.size():
		return
	
	# ANTI-MIRROR: Prevent selecting the same character as opponent
	if player_id == 1 and index == player2_selected_index:
		print("Player 1 cannot select same character as Player 2")
		return
	elif player_id == 2 and index == player1_selected_index:
		print("Player 2 cannot select same character as Player 1") 
		return

	var boxes = player1_boxes if player_id == 1 else player2_boxes
	var button = player1_ready_button if player_id == 1 else player2_ready_button
	var character = available_characters[index]

	boxes[index].set_selected(true)
	button.disabled = false
	select_sound.play()

	if player_id == 1:
		player1_character = character
		player1_selected_index = index
		button.text = "READY UP"
		
		# If AI had selected the same character, make them unselect
		if is_pve_mode and player2_selected_index == index:
			unselect_character(2)
			ai_selection_phase = "hovering"
			ai_selection_timer = 0.0
	else:
		player2_character = character
		player2_selected_index = index
		if is_pve_mode:
			button.text = "AI THINKING..."
		else:
			button.text = "READY UP"
	
	# NEW: Update unavailable states for both grids
	update_character_availability()

func unselect_character(player_id: int):
	var boxes = player1_boxes if player_id == 1 else player2_boxes
	var index = player1_selected_index if player_id == 1 else player2_selected_index
	var button = player1_ready_button if player_id == 1 else player2_ready_button

	if index < 0 or index >= boxes.size():
		return

	boxes[index].set_selected(false)
	boxes[index].set_hovered(true)
	button.disabled = true
	select_sound.play()

	if player_id == 1:
		player1_character = null
		player1_selected_index = -1
		player1_hovered_index = index
		button.text = "SELECT FIRST"
	else:
		player2_character = null
		player2_selected_index = -1
		player2_hovered_index = index
		if is_pve_mode:
			button.text = "AI WAITING..."
		else:
			button.text = "SELECT FIRST"
	
	# NEW: Update unavailable states for both grids
	update_character_availability()

func _on_player1_ready():
	player1_ready = true
	player1_ready_button.disabled = true
	player1_ready_button.text = "READY!"
	ready_sound.play()
	check_both_ready()

func _on_player2_ready():
	player2_ready = true
	player2_ready_button.disabled = true
	if is_pve_mode:
		player2_ready_button.text = "AI READY!"
	else:
		player2_ready_button.text = "READY!"
	ready_sound.play()
	check_both_ready()

func check_both_ready():
	if player1_ready and player2_ready:
		await get_tree().create_timer(0.5).timeout
		start_match()

func start_match():
	set_process(false)
	start_sound.play()
	await get_tree().create_timer(0.5).timeout
	if music_player:
		music_player.stop()

	var gsm = get_node_or_null("/root/GameState_Manager")
	if gsm:
		gsm.player1_character = player1_character
		gsm.player2_character = player2_character
		gsm.start_fight()
	else:
		get_tree().change_scene_to_file("res://Scenes/fight_scene.tscn")
