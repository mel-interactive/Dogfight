
# SpecialAttackState.gd
extends AttackState
class_name SpecialAttackState

var slide_timer: float = 0.0
var slide_duration: float = 0.3
var sliding: bool = false
var start_position: Vector2
var target_position: Vector2

func _ready():
	attack_type = "special"

func enter():
	# Consume special meter immediately
	character.special_meter = 0
	character.emit_signal("special_meter_changed", character.special_meter)
	
	# Trigger sliding for both characters
	start_dual_character_slide()

func start_dual_character_slide():
	# Store our starting position and get target
	start_position = character.global_position
	target_position = get_character_spawn_position(character.player_number)
	
	# Also trigger opponent to slide to their spawn position
	if character.opponent:
		character.opponent.slide_to_spawn_position(slide_duration)
	
	# Check if we need to slide
	if start_position.distance_to(target_position) > 10.0:
		sliding = true
		slide_timer = 0.0
		
		# Start speed lines for the attacking character too
		character.visual_component.start_speed_lines()
		
		print("Special attack: both characters sliding - attacker from ", start_position, " to ", target_position)
	else:
		sliding = false
		print("Special attack: attacker already at spawn, starting immediately")
		super.enter()

func update(delta):
	if sliding:
		slide_timer += delta
		var slide_progress = slide_timer / slide_duration
		
		# Deceleration curve (ease-out)
		var eased_progress = 1.0 - pow(1.0 - slide_progress, 3.0)
		eased_progress = clamp(eased_progress, 0.0, 1.0)
		
		# Calculate movement direction for speed lines
		var movement_direction = (target_position - start_position).normalized()
		character.visual_component.update_speed_lines_direction(movement_direction)
		
		# Interpolate position
		character.global_position = start_position.lerp(target_position, eased_progress)
		
		# Stop sliding when complete
		if slide_progress >= 1.0:
			sliding = false
			character.global_position = target_position
			
			# Stop speed lines
			character.visual_component.stop_speed_lines()
			
			print("Special attack: slide complete, starting attack")
			super.enter()  # Start the actual attack
	else:
		# Normal attack behavior
		super.update(delta)

func get_character_spawn_position(player_num: int) -> Vector2:
	# Try to get the spawn position from the fight scene
	var fight_scene = character.get_tree().current_scene
	if fight_scene.has_node("Positions/Player" + str(player_num) + "Position"):
		return fight_scene.get_node("Positions/Player" + str(player_num) + "Position").global_position
	
	# Fallback: estimate based on player number and screen width
	var viewport_size = character.get_viewport().get_visible_rect().size
	if player_num == 1:
		return Vector2(viewport_size.x * 0.25, character.global_position.y)
	else:
		return Vector2(viewport_size.x * 0.75, character.global_position.y)

func get_animation_name() -> String:
	return "special_attack"

func get_attack_sound() -> AudioStream:
	return character.character_data.special_attack_sound

func get_attack_duration() -> float:
	return character.character_data.special_attack_duration
