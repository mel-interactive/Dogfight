# PlayerCharacter.gd - Enhanced with win/lose state input blocking
extends BaseCharacter
class_name PlayerCharacter

# Player ID (1 or 2)
@export var player_id: int = 1

# Input action mappings
var input_prefix: String

func _ready():
	super._ready()
	
	# If we don't have character data assigned in the editor, create a default one with player colors
	if not character_data:
		character_data = CharacterData.new()
		if player_id == 1:
			character_data.color = Color.BLUE
		else:
			character_data.color = Color.RED
	
	# Update debug sprite with character color if we created it
	if has_node("DebugSprite") and not character_data.sprite_texture:
		var img = Image.create(50, 100, false, Image.FORMAT_RGBA8)
		img.fill(character_data.color)
		var tex = ImageTexture.create_from_image(img)
		$DebugSprite.texture = tex
	
	# Set up input prefix based on player ID
	input_prefix = "p" + str(player_id) + "_"

func _physics_process(delta):
	# Handle player input
	handle_input()
	
	# Call parent physics process
	super._physics_process(delta)

func handle_input():
	# Skip input handling during intro sequence
	var fight_scene = get_tree().current_scene as FightScene
	if fight_scene and fight_scene.intro_sequence_active:
		return
	
	# Skip input handling if defeated, victorious, or during attacks
	var current_state_name = state_machine.get_current_state_name()
	if current_state_name in ["Defeat", "Victory", "LightAttack", "HeavyAttack", "SpecialAttack", "UltimateAttack", "Hit"]:
		return
	
	# Attacks (check these FIRST to stop movement)
	if Input.is_action_just_pressed(input_prefix + "light"):
		velocity.x = 0  # Stop movement immediately
		light_attack()
		return  # Don't process movement this frame
	
	if Input.is_action_just_pressed(input_prefix + "heavy"):
		velocity.x = 0  # Stop movement immediately
		heavy_attack()
		return  # Don't process movement this frame
	
	# Special attack
	if Input.is_action_just_pressed(input_prefix + "special") and can_use_special():
		velocity.x = 0  # Stop movement immediately
		special_attack()
		return  # Don't process movement this frame
	
	# Ultimate attack
	if Input.is_action_just_pressed(input_prefix + "ultimate") and can_use_ultimate():
		velocity.x = 0  # Stop movement immediately
		ultimate_attack()
		return  # Don't process movement this frame
	
	# Movement (left/right) - only processed if no attacks happened
	var move_dir = 0
	if Input.is_action_pressed(input_prefix + "left"):
		move_dir -= 1
	if Input.is_action_pressed(input_prefix + "right"):
		move_dir += 1
	
	if move_dir != 0 and can_move():
		velocity.x = move_dir * character_data.move_speed
		current_state = CharacterState.MOVING
	else:
		velocity.x = 0
		if current_state == CharacterState.MOVING:
			current_state = CharacterState.IDLE
	
	# Block (hold action)
	if Input.is_action_pressed(input_prefix + "block"):
		block()
	elif current_state == CharacterState.BLOCKING:
		stop_blocking()
