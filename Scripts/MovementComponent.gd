# MovementComponent.gd
extends Node
class_name MovementComponent

var character: BaseCharacter

func _ready():
	character = get_parent()

func apply_movement_constraints():
	var viewport_size = character.get_viewport().get_visible_rect().size
	var sprite_width = 50  # Default width, or get from sprite if available
	
	if character.sprite and character.sprite.sprite_frames and character.sprite.animation != "":
		var current_frame = character.sprite.sprite_frames.get_frame_texture(character.sprite.animation, character.sprite.frame)
		if current_frame:
			sprite_width = current_frame.get_width() * character.sprite.scale.x
	
	# Screen boundaries (allow sprites to go halfway offscreen)
	var left_boundary = -(sprite_width * 0.5)
	var right_boundary = viewport_size.x + (sprite_width * 0.5)
	
	# Check opponent overlap constraint
	if character.opponent:
		var my_x = character.global_position.x
		var opponent_x = character.opponent.global_position.x
		var min_distance = sprite_width * 0.75  # Allow up to 25% overlap (75% minimum distance)
		
		# If moving towards opponent and would overlap too much
		if character.velocity.x > 0 and my_x < opponent_x:  # Moving right towards opponent
			var future_x = my_x + character.velocity.x * character.get_physics_process_delta_time()
			if future_x + min_distance > opponent_x:
				character.velocity.x = 0
		elif character.velocity.x < 0 and my_x > opponent_x:  # Moving left towards opponent
			var future_x = my_x + character.velocity.x * character.get_physics_process_delta_time()
			if future_x - min_distance < opponent_x:
				character.velocity.x = 0
	
	# Apply screen boundary constraints
	var future_x = character.global_position.x + character.velocity.x * character.get_physics_process_delta_time()
	
	if future_x < left_boundary:
		character.velocity.x = 0
		character.global_position.x = left_boundary
	elif future_x > right_boundary:
		character.velocity.x = 0
		character.global_position.x = right_boundary

func move_left():
	if can_move():
		character.velocity.x = -character.character_data.move_speed
		character.state_machine.change_state("Moving")

func move_right():
	if can_move():
		character.velocity.x = character.character_data.move_speed
		character.state_machine.change_state("Moving")

func stop_moving():
	character.velocity.x = 0
	if character.state_machine.get_current_state_name() == "Moving":
		character.state_machine.change_state("Idle")

func can_move() -> bool:
	var current_state = character.state_machine.get_current_state_name()
	return (current_state == "Idle" or current_state == "Moving") and current_state != "Hit"

func get_movement_animation() -> String:
	if character.movement_direction == 0:
		return "idle"
	
	var is_moving_forward: bool
	if character.player_number == 1:
		is_moving_forward = (character.movement_direction > 0)
	else:
		is_moving_forward = (character.movement_direction < 0)
	
	if is_moving_forward:
		return "run_forward" if character.sprite.sprite_frames.has_animation("run_forward") else "idle"
	else:
		return "run_backward" if character.sprite.sprite_frames.has_animation("run_backward") else "idle"
