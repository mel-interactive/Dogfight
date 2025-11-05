# AICharacter.gd - Simple AI that inherits from BaseCharacter
extends BaseCharacter
class_name AICharacter

# AI Configuration
@export var ai_difficulty: float = 1.2  # 0.5 = easy, 1.0 = normal, 1.5 = hard
@export var reaction_time: float = 0.2   # How fast AI reacts (seconds)

# AI State
var ai_timer: float = 0.0
var next_action_time: float = 0.0
var current_ai_state: String = "thinking"
var last_distance_to_opponent: float = 0.0

# IMPORTANT: Control scheme support - AI won't act until this is true
var ai_active: bool = true

# NEW: Anti-spam tracking
var recent_hits_taken: int = 0
var last_hit_time: float = 0.0
var hit_reset_timer: float = 2.0  # Reset hit counter after 2 seconds

# NEW: Personal space tracking
var time_too_close: float = 0.0
var too_close_threshold: float = 1.0  # Back up if too close for 1 second

# NEW: Falling item dodge tracking
var is_dodging_item: bool = false
var dodge_direction: int = 1 # -1 = left, 1 = right
var dodge_timer: float = 0.0
var dodge_duration: float = 1.2  # How long to keep dodging

func _ready():
	super._ready()
	# Player number is set by FightScene, no need to hardcode it here
	
	# NEW: Connect to damage events to track hits
	if has_signal("health_changed"):
		connect("health_changed", _on_ai_health_changed)

func _physics_process(delta):
	# Handle AI logic instead of player input
	handle_ai_logic(delta)
	
	# Call parent physics process
	super._physics_process(delta)

func handle_ai_logic(delta):
	# IMPORTANT: Don't do anything if AI is not active (for control scheme)
	if not ai_active:
		return
	
	# Skip AI during intro sequence or if defeated/victorious
	var fight_scene = get_tree().current_scene as FightScene
	if fight_scene and fight_scene.intro_sequence_active:
		return
	
	# NEW: Skip AI logic if block stunned
	if get("is_block_stunned") == true:
		return
	
	var current_state_name = state_machine.get_current_state_name()
	if current_state_name in ["Defeat", "Victory"]:
		return
	
	# Don't interrupt ongoing attacks
	if current_state_name in ["LightAttack", "HeavyAttack", "SpecialAttack", "UltimateAttack", "Hit"]:
		return
	
	# NEW: Stop movement if frozen, but continue with other AI decisions
	if not can_move():
		velocity.x = 0  # Stop any ongoing movement
		is_dodging_item = false  # Cancel dodge if frozen
		# Don't return here - AI can still make other decisions like stopping blocking
	
	ai_timer += delta
	
	# NEW: Update hit tracking
	update_hit_tracking(delta)
	
	# NEW: Handle active dodge
	if is_dodging_item:
		dodge_timer -= delta
		if dodge_timer <= 0.0:
			is_dodging_item = false
			stop_moving()
			print("AI: Finished dodging")
		else:
			# Keep moving in dodge direction
			if dodge_direction < 0:
				move_left()
			else:
				move_right()
			return  # Skip other AI logic while dodging
	
	# NEW: PRIORITY CHECK - Check for falling items and dodge!
	check_and_dodge_falling_items()
	if is_dodging_item:
		return  # Exit early if we started dodging
	
	# Wait for reaction time before making decisions
	if ai_timer < next_action_time:
		return
	
	# Make AI decision
	make_ai_decision()

# NEW: Simplified and more reliable falling item detection and dodge
func check_and_dodge_falling_items():
	# Get all nodes in the scene
	var fight_scene = get_tree().current_scene
	if not fight_scene:
		return
	
	# Look for FallingItem nodes
	var camera_effects = fight_scene.get_node_or_null("CameraEffects")
	if not camera_effects:
		return
	
	var my_x = global_position.x
	var my_y = global_position.y
	var danger_threshold_x = 400.0  # Increased from 100 - wider detection
	var danger_threshold_y = 450.0  # Increased from 400 - detect earlier
	
	for child in camera_effects.get_children():
		# Check if this is a falling item
		if child.has_method("initialize") and child.get("is_falling") == true:
			var item_x = child.global_position.x
			var item_y = child.global_position.y
			
			var x_distance = abs(item_x - my_x)
			var y_distance = my_y - item_y  # Positive if item is above us
			
			# Check if item is above us and getting close
			if y_distance > 0 and y_distance < danger_threshold_y and x_distance < danger_threshold_x:
				# Check AI difficulty for dodge success
				var dodge_success_chance = 0.4 + (ai_difficulty * 0.4)  # 40% base + up to 60% bonus
				
				if randf() > dodge_success_chance:
					continue
				
				if not can_move():
					continue
				
				# Start dodging!
				is_dodging_item = true
				dodge_timer = dodge_duration
				
				# DEFAULT: Dodge right (away from player who is on the left)
				# Only dodge left if we're at the right edge of the screen
				var viewport_size = get_viewport_rect().size
				var screen_right_edge = viewport_size.x - 150.0  # 150px margin from edge
				
				if my_x >= screen_right_edge:
					# Too close to right edge, dodge left instead
					dodge_direction = -1
					move_left()
				else:
					# Safe to dodge right
					dodge_direction = 1
					move_right()
				
				return  # Only dodge one item at a time


func make_ai_decision():
	if not opponent or not character_data:
		return
	
	var distance_to_opponent = abs(global_position.x - opponent.global_position.x)
	var opponent_state = opponent.state_machine.get_current_state_name()
	
	# Use character's actual attack ranges
	var light_range = character_data.light_attack_range
	var heavy_range = character_data.heavy_attack_range
	var special_range = character_data.special_attack_range
	var ultimate_range = character_data.ultimate_attack_range
	
	# Calculate dynamic ranges based on character's attacks
	var max_attack_range = max(light_range, max(heavy_range, max(special_range, ultimate_range)))
	var preferred_range = light_range * 0.9  # Back to original
	var min_range = 150
	var too_close_distance = 200
	
	# NEW: Track how long we've been too close
	if distance_to_opponent < too_close_distance:
		time_too_close += ai_timer - next_action_time + 0.1  # Approximate delta
	else:
		time_too_close = 0.0  # Reset if we have space
	
	# NEW: Calculate spam defense modifier based on recent hits
	var spam_defense_modifier = 1.0 + (recent_hits_taken * 0.3)  # +30% per recent hit
	var is_being_spammed = recent_hits_taken >= 2
	
	# 1. Try special/ultimate if available and in range
	if can_use_ultimate() and distance_to_opponent <= ultimate_range and distance_to_opponent >= min_range:
		if randf() < 0.3 * ai_difficulty:
			ultimate_attack()
			set_next_action_delay(1.5)
			return
	
	if can_use_special() and distance_to_opponent <= special_range and distance_to_opponent >= min_range:
		if randf() < 0.4 * ai_difficulty:
			special_attack()
			set_next_action_delay(1.0)
			return
	
	# 2. ENHANCED: Block if opponent is attacking (much more likely if being spammed)
	if opponent_state in ["LightAttack", "HeavyAttack"] and distance_to_opponent < max_attack_range * 1.2:
		var block_chance = 0.7 * ai_difficulty * spam_defense_modifier
		block_chance = min(block_chance, 0.95)  # Cap at 95%
		if randf() < block_chance:
			block()
			set_next_action_delay(0.4)
			return
	elif is_blocking():
		stop_blocking()
	
	# 3. NEW: Back up if we've been too close for too long
	if time_too_close >= too_close_threshold:
		if can_move():
			# Definitely back up - we've been crowding too long
			if opponent.global_position.x > global_position.x:
				move_left()
			else:
				move_right()
			set_next_action_delay(0.3)
			return
		else:
			set_next_action_delay(0.2)
			return
	
	# 4. ENHANCED: Back up if WAY too close (immediate retreat)
	if distance_to_opponent < min_range or (is_being_spammed and distance_to_opponent < preferred_range):
		if can_move():
			var retreat_chance = 0.7 + (recent_hits_taken * 0.2)  # Base 70% + 20% per hit
			if randf() < retreat_chance:
				if opponent.global_position.x > global_position.x:
					move_left()
				else:
					move_right()
				set_next_action_delay(0.15)
				return
		else:
			set_next_action_delay(0.2)
			return
	
	# 5. Attack if in range (normal aggression restored)
	if distance_to_opponent >= min_range and distance_to_opponent <= heavy_range:
		if opponent_state in ["Idle", "Moving"]:
			# Reduce aggression if being spammed
			var attack_chance = 1.0
			if is_being_spammed:
				attack_chance = 0.3  # Much less likely to attack when being spammed
			
			if randf() < attack_chance:
				var attack_choice = randf()
				if distance_to_opponent <= light_range and attack_choice < 0.7:
					light_attack()
					set_next_action_delay(0.5)
					return
				elif distance_to_opponent <= heavy_range:
					heavy_attack()
					set_next_action_delay(0.7)
					return
	
	# 6. Move closer if too far for any attack (less aggressive if being spammed)
	if distance_to_opponent > preferred_range and not is_being_spammed:
		if can_move():
			if opponent.global_position.x > global_position.x:
				move_right()
			else:
				move_left()
			set_next_action_delay(0.1)
			return
		else:
			set_next_action_delay(0.2)
			return
	
	# 7. Good position - wait and see
	if can_move():
		stop_moving()
	set_next_action_delay(0.3)



# NEW: Track when AI takes damage to detect spam
func _on_ai_health_changed(new_health):
	# If health decreased, we took damage
	if new_health < current_health:
		recent_hits_taken += 1
		last_hit_time = ai_timer
		print("AI: Took hit! Recent hits: ", recent_hits_taken)

# NEW: Reset hit counter after time passes
func update_hit_tracking(delta):
	# Reset hit counter if enough time has passed since last hit
	if ai_timer - last_hit_time > hit_reset_timer:
		if recent_hits_taken > 0:
			recent_hits_taken = 0
			print("AI: Hit counter reset - no longer being spammed")

func set_next_action_delay(base_delay: float):
	# Add some randomness to make AI less predictable
	var randomness = randf_range(0.8, 1.2)
	var difficulty_modifier = 2.0 - ai_difficulty  # Easier AI = slower reactions
	next_action_time = ai_timer + (base_delay * difficulty_modifier * randomness)

# Override handle_input to do nothing (AI doesn't use input)
func handle_input():
	pass
