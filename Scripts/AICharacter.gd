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
		# Don't return here - AI can still make other decisions like stopping blocking
	
	ai_timer += delta
	
	# NEW: Update hit tracking
	update_hit_tracking(delta)
	
	# Wait for reaction time before making decisions
	if ai_timer < next_action_time:
		return
	
	# Make AI decision
	make_ai_decision()

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
	var preferred_range = light_range * 0.9  # Stay just within light attack range
	var min_range = 50.0  # Minimum personal space
	
	print("AI: Distance: ", distance_to_opponent, " Light range: ", light_range, " Preferred: ", preferred_range)
	print("AI: Recent hits taken: ", recent_hits_taken)
	
	# NEW: Calculate spam defense modifier based on recent hits
	var spam_defense_modifier = 1.0 + (recent_hits_taken * 0.3)  # +30% per recent hit
	var is_being_spammed = recent_hits_taken >= 2
	
	# 1. Try special/ultimate if available and in range
	if can_use_ultimate() and distance_to_opponent <= ultimate_range and distance_to_opponent >= min_range:
		if randf() < 0.3 * ai_difficulty:
			print("AI: Using ultimate attack")
			ultimate_attack()
			set_next_action_delay(1.5)
			return
	
	if can_use_special() and distance_to_opponent <= special_range and distance_to_opponent >= min_range:
		if randf() < 0.4 * ai_difficulty:
			print("AI: Using special attack")
			special_attack()
			set_next_action_delay(1.0)
			return
	
	# 2. ENHANCED: Block if opponent is attacking (much more likely if being spammed)
	if opponent_state in ["LightAttack", "HeavyAttack"] and distance_to_opponent < max_attack_range * 1.2:
		var block_chance = 0.7 * ai_difficulty * spam_defense_modifier
		block_chance = min(block_chance, 0.95)  # Cap at 95%
		if randf() < block_chance:
			print("AI: Blocking incoming attack (spam defense: ", spam_defense_modifier, ")")
			block()
			set_next_action_delay(0.4)
			return
	elif is_blocking():
		print("AI: Stopping block")
		stop_blocking()
	
	# 3. ENHANCED: Back up if too close (much more likely if being spammed)
	if distance_to_opponent < min_range or (is_being_spammed and distance_to_opponent < preferred_range):
		if can_move():
			var retreat_chance = 0.6 + (recent_hits_taken * 0.2)  # Base 60% + 20% per hit
			if randf() < retreat_chance:
				print("AI: Backing up (spam defense, hits: ", recent_hits_taken, ")")
				if opponent.global_position.x > global_position.x:
					move_left()
				else:
					move_right()
				set_next_action_delay(0.15)
				return
		else:
			print("AI: Want to back up but movement frozen")
			set_next_action_delay(0.2)
			return
	
	# 4. MODIFIED: Attack if in range (less likely if being spammed)
	if distance_to_opponent >= min_range and distance_to_opponent <= heavy_range:
		if opponent_state in ["Idle", "Moving"]:
			# Reduce aggression if being spammed
			var attack_chance = 1.0
			if is_being_spammed:
				attack_chance = 0.3  # Much less likely to attack when being spammed
			
			if randf() < attack_chance:
				var attack_choice = randf()
				if distance_to_opponent <= light_range and attack_choice < 0.7:
					print("AI: Light attack (in range)")
					light_attack()
					set_next_action_delay(0.5)
					return
				elif distance_to_opponent <= heavy_range:
					print("AI: Heavy attack (in range)")
					heavy_attack()
					set_next_action_delay(0.7)
					return
			else:
				print("AI: Skipping attack due to spam defense")
	
	# 5. Move closer if too far for any attack (less aggressive if being spammed)
	if distance_to_opponent > preferred_range and not is_being_spammed:
		if can_move():
			print("AI: Moving closer (current: ", distance_to_opponent, " target: ", preferred_range, ")")
			if opponent.global_position.x > global_position.x:
				move_right()
			else:
				move_left()
			set_next_action_delay(0.1)
			return
		else:
			print("AI: Want to move closer but movement frozen")
			set_next_action_delay(0.2)
			return
	
	# 6. Good position - wait and see
	if can_move():
		print("AI: Good position, waiting")
		stop_moving()
	else:
		print("AI: Good position but movement frozen, just waiting")
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
