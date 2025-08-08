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

func _ready():
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
	player2_ready_button.pressed.connect(_on_player2_ready)

	player1_ready_button.disabled = true
	player2_ready_button.disabled = true

func _process(_delta):
	handle_input(1)
	handle_input(2)

	if player1_ready and player2_ready:
		start_match()

func setup_audio():
	navigation_sound.stream = navigation_audio
	select_sound.stream = select_audio
	ready_sound.stream = ready_audio
	start_sound.stream = start_audio

	if background_music:
		music_player.stream = background_music
		music_player.play()

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

	if selected != -1:
		if Input.is_action_just_pressed(prefix + "special"):
			unselect_character(player_id)
		return

	var new_index = current
	if Input.is_action_just_pressed(prefix + "left") and current % columns > 0:
		new_index -= 1
	elif Input.is_action_just_pressed(prefix + "right") and current % columns < columns - 1 and current + 1 < total:
		new_index += 1
	elif Input.is_action_just_pressed(prefix + "light") and current - columns >= 0:
		new_index -= columns
	elif Input.is_action_just_pressed(prefix + "heavy") and current + columns < total:
		new_index += columns
	elif Input.is_action_just_pressed(prefix + "special"):
		select_character(player_id, current)

	if new_index != current:
		if player_id == 1:
			player1_hovered_index = new_index
		else:
			player2_hovered_index = new_index
		update_hover(player_id, new_index)
		navigation_sound.play()

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

	var boxes = player1_boxes if player_id == 1 else player2_boxes
	var button = player1_ready_button if player_id == 1 else player2_ready_button
	var character = available_characters[index]

	boxes[index].set_selected(true)
	button.disabled = false
	select_sound.play()

	if player_id == 1:
		player1_character = character
		player1_selected_index = index
	else:
		player2_character = character
		player2_selected_index = index

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
	else:
		player2_character = null
		player2_selected_index = -1
		player2_hovered_index = index

func _on_player1_ready():
	player1_ready = true
	player1_ready_button.disabled = true
	player1_ready_button.text = "READY!"
	ready_sound.play()
	check_both_ready()

func _on_player2_ready():
	player2_ready = true
	player2_ready_button.disabled = true
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
