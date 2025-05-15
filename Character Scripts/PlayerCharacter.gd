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
	
	# Face the opponent
	face_opponent()
	
	# Call parent physics process
	super._physics_process(delta)

func handle_input():
	# Skip input handling if defeated or attacking
	if current_state == CharacterState.DEFEAT or \
	   current_state == CharacterState.ATTACKING_LIGHT or \
	   current_state == CharacterState.ATTACKING_HEAVY or \
	   current_state == CharacterState.SPECIAL_ATTACK or \
	   current_state == CharacterState.ULTIMATE_ATTACK or \
	   current_state == CharacterState.HIT:
		return
	
	# Movement (left/right)
	var move_dir = 0
	if Input.is_action_pressed(input_prefix + "left"):
		move_dir -= 1
	if Input.is_action_pressed(input_prefix + "right"):
		move_dir += 1
	
	if move_dir != 0:
		velocity.x = move_dir * character_data.move_speed
		current_state = CharacterState.MOVING
	else:
		velocity.x = 0
		if current_state == CharacterState.MOVING:
			current_state = CharacterState.IDLE
	
	# Attacks
	if Input.is_action_just_pressed(input_prefix + "light"):
		light_attack()
	
	if Input.is_action_just_pressed(input_prefix + "heavy"):
		heavy_attack()
	
	# Block (hold action)
	if Input.is_action_pressed(input_prefix + "block"):
		block()
	elif current_state == CharacterState.BLOCKING:
		stop_blocking()
	
	# Special attack
	if Input.is_action_just_pressed(input_prefix + "special") and can_use_special():
		special_attack()
	
	# Ultimate attack
	if Input.is_action_just_pressed(input_prefix + "ultimate") and can_use_ultimate():
		ultimate_attack()
