# PlayerCharacter.gd - Simplified to just queue commands
extends BaseCharacter
class_name PlayerCharacter

# Player ID (1 or 2)
@export var player_id: int = 1

# Input action mappings
var input_prefix: String

func _ready():
	super._ready()
	
	# Use player_number from BaseCharacter (set by FightScene) instead of player_id
	# This ensures proper input mapping when created dynamically
	if player_number > 0:
		player_id = player_number
	
	# If we don't have character data assigned in the editor, create a default one with player colors
	if not character_data:
		character_data = CharacterData.new()
		if player_id == 1:
			character_data.color = Color.BLUE
		else:
			character_data.color = Color.RED
	
	# Set up input prefix based on player ID
	input_prefix = "p" + str(player_id) + "_"
	print("PlayerCharacter: Player ", player_id, " using input prefix: ", input_prefix)

func _physics_process(delta):
	# Convert input to commands
	read_input_to_commands()
	
	# Parent handles the rest (command processing + physics)
	super._physics_process(delta)

func read_input_to_commands():
	# Attacks first (they stop movement)
	if Input.is_action_just_pressed(input_prefix + "light"):
		command_queue.append("light_attack")
		return
	
	if Input.is_action_just_pressed(input_prefix + "heavy"):
		command_queue.append("heavy_attack")
		return
	
	if Input.is_action_just_pressed(input_prefix + "special"):
		command_queue.append("special_attack")
		return
	
	if Input.is_action_just_pressed(input_prefix + "ultimate"):
		command_queue.append("ultimate_attack")
		return
	
	# Block - FIXED: Only queue commands on state changes
	var is_block_pressed = Input.is_action_pressed(input_prefix + "block")
	var currently_blocking = is_blocking()
	
	if is_block_pressed and not currently_blocking:
		# Just started blocking
		command_queue.append("block")
	elif not is_block_pressed and currently_blocking:
		# Just stopped blocking
		command_queue.append("stop_block")
	
	# Movement (only if no attacks)
	var move_dir = 0
	if Input.is_action_pressed(input_prefix + "left"):
		move_dir -= 1
	if Input.is_action_pressed(input_prefix + "right"):
		move_dir += 1
	
	if move_dir < 0:
		command_queue.append("move_left")
	elif move_dir > 0:
		command_queue.append("move_right")
	else:
		command_queue.append("stop_move")
