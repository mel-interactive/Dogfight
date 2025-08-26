# CombatComponent.gd - Enhanced with reaction system integration
extends Node
class_name CombatComponent

var character: BaseCharacter

func _ready():
	character = get_parent()

func _process(delta):
	# Combo timer
	if character.combo_count > 0:
		character.combo_timer -= delta
		if character.combo_timer <= 0:
			character.combo_count = 0
			character.emit_signal("combo_changed", character.combo_count)
			EventBus.emit_signal("combo_changed", character, character.combo_count)
	
	# Charge ultimate meter
	charge_ultimate_meter(character.character_data.ultimate_meter_gain_per_second * delta)

func apply_attack_hit():
	if not character.opponent:
		return
	
	var damage: int = 0
	var attack_range: float = 0
	var ignore_block: bool = false
	var attack_type: String = ""
	
	var state_name = character.state_machine.get_current_state_name()
	match state_name:
		"LightAttack":
			damage = character.character_data.light_attack_damage
			attack_range = character.character_data.light_attack_range
			ignore_block = false
			attack_type = "light"
		"HeavyAttack":
			damage = character.character_data.heavy_attack_damage
			attack_range = character.character_data.heavy_attack_range
			ignore_block = false
			attack_type = "heavy"
		"SpecialAttack":
			damage = character.character_data.special_attack_damage
			attack_range = character.character_data.special_attack_range
			ignore_block = true
			attack_type = "special_attack"  # Match the ReactionData enum
		"UltimateAttack":
			damage = character.character_data.ultimate_attack_damage
			attack_range = character.character_data.ultimate_attack_range
			ignore_block = true
			attack_type = "ultimate_attack"  # Match the ReactionData enum
	
	# Check if opponent is in range
	if is_opponent_in_attack_range(attack_range):
		print("CombatComponent: Opponent in range for ", attack_type)
		
		if ignore_block:
			print("CombatComponent: Processing special/ultimate attack")
			# For special/ultimate attacks, reaction was already triggered in attack state
			# Just apply damage here
			var damage_taken = character.opponent.take_damage(damage, true)
			if damage_taken:
				register_hit()
				EventBus.emit_signal("attack_hit", character, character.opponent, damage, attack_type)
		else:
			print("CombatComponent: Processing normal attack")
			# Normal attacks check for blocking and apply damage
			var is_blocked = character.opponent.is_blocking()
			
			# Apply damage regardless of blocking (blocking just reduces it)
			var damage_taken = character.opponent.take_damage(damage, false)
			
			if is_blocked:
				# NEW: Apply block stun to attacker
				apply_block_stun()
				EventBus.emit_signal("attack_blocked", character, character.opponent, attack_type)
			else:
				# Only register hit if not blocked
				if damage_taken:
					register_hit()
					EventBus.emit_signal("attack_hit", character, character.opponent, damage, attack_type)
	else:
		print("CombatComponent: Opponent NOT in range for ", attack_type)

# NEW: Trigger reaction at the START of special/ultimate attacks for better timing
func trigger_attack_reaction(attack_type: String):
	print("CombatComponent: trigger_attack_reaction called with attack_type: ", attack_type)
	
	if not character.opponent or not character.character_data:
		print("  FAILED: No opponent or character data")
		return
	
	# Only handle special and ultimate attacks
	if attack_type != "special_attack" and attack_type != "ultimate_attack":
		print("  SKIPPED: Not a special or ultimate attack")
		return
	
	# Check if opponent is in range first
	var attack_range: float = 0
	match attack_type:
		"special_attack":
			attack_range = character.character_data.special_attack_range
		"ultimate_attack":
			attack_range = character.character_data.ultimate_attack_range
	
	if not is_opponent_in_attack_range(attack_range):
		print("  SKIPPED: Opponent not in range")
		return
	
	print("  Attempting to trigger reaction on opponent: ", character.opponent.character_data.character_name if character.opponent.character_data else "NO DATA")
	
	# Trigger the reaction immediately
	var played_reaction = character.opponent.play_reaction_to_attack(character, attack_type)
	
	if played_reaction:
		print("SUCCESS: Triggered reaction: ", character.opponent.character_data.character_name, " reacting to ", character.character_data.character_name, "'s ", attack_type)
	else:
		print("NO REACTION: No specific reaction found for: ", character.opponent.character_data.character_name, " vs ", character.character_data.character_name, "'s ", attack_type)

# NEW: Try to play character-specific reaction for special/ultimate attacks
func try_play_character_reaction(attack_type: String) -> bool:
	print("CombatComponent: try_play_character_reaction called with attack_type: ", attack_type)
	
	if not character.opponent or not character.character_data:
		print("  FAILED: No opponent or character data")
		return false
	
	# Only handle special and ultimate attacks
	if attack_type != "special_attack" and attack_type != "ultimate_attack":
		print("  SKIPPED: Not a special or ultimate attack")
		return false
	
	print("  Attempting to play reaction on opponent: ", character.opponent.character_data.character_name if character.opponent.character_data else "NO DATA")
	
	# Check if opponent has a specific reaction to this character's attack
	var played_reaction = character.opponent.play_reaction_to_attack(character, attack_type)
	
	if played_reaction:
		print("SUCCESS: Playing specific reaction: ", character.opponent.character_data.character_name, " reacting to ", character.character_data.character_name, "'s ", attack_type)
		return true
	else:
		print("NO REACTION: No specific reaction found for: ", character.opponent.character_data.character_name, " vs ", character.character_data.character_name, "'s ", attack_type)
		return false

func is_opponent_in_attack_range(attack_range: float) -> bool:
	if not character.opponent:
		return false
	
	var my_x = character.global_position.x
	var opponent_x = character.opponent.global_position.x
	
	if character.player_number == 1:
		return opponent_x >= my_x and opponent_x <= (my_x + attack_range)
	else:
		return opponent_x <= my_x and opponent_x >= (my_x - attack_range)

func take_damage(damage_amount: int, ignore_block: bool) -> bool:
	# If ignore_block is true, skip all blocking logic
	if ignore_block:
		character.current_health -= damage_amount
		character.current_health = max(0, character.current_health)
		
		character.emit_signal("health_changed", character.current_health)
		EventBus.emit_signal("character_health_changed", character, character.current_health)
		
		if character.current_health <= 0:
			character.state_machine.change_state("Defeat")
		else:
			# For special/ultimate attacks, the reaction system handles the hit animation
			# We don't need to go to Hit state because the reaction replaces it
			# NO PITCH VARIATION for specials/ultimates - keep their dramatic impact
			character.play_sound(character.character_data.hit_sound)
			# NO WHITE FLASH for ignore_block attacks (specials/ultimates)
		
		return true  # Damage was taken
	
	# Normal damage with blocking check
	var blocked = character.is_blocking()
	
	if blocked:
		# Convert to int to avoid narrowing conversion warning
		damage_amount = int(damage_amount * 0.2)
		character.play_sound(character.character_data.block_sound)
		# WHITE FLASH only happens when blocking
		character.visual_component.do_simple_shake()
		
		# COMBO BREAKER: Successful block ends opponent's combo
		if character.opponent:
			character.opponent.combo_count = 0
			character.opponent.combo_timer = 0.0
			character.opponent.emit_signal("combo_changed", character.opponent.combo_count)
			EventBus.emit_signal("combo_changed", character.opponent, character.opponent.combo_count)
			print("Combo broken by successful block!")
	else:
		play_hit_sound_with_pitch_variation()
		# NO WHITE FLASH for normal hits
	
	character.current_health -= damage_amount
	character.current_health = max(0, character.current_health)
	
	character.emit_signal("health_changed", character.current_health)
	EventBus.emit_signal("character_health_changed", character, character.current_health)
	
	if character.current_health <= 0:
		character.state_machine.change_state("Defeat")
	elif not blocked:
		# ATTACK PRIORITY: Don't interrupt if character is currently attacking
		var current_state = character.state_machine.get_current_state_name()
		if current_state not in ["LightAttack", "HeavyAttack", "SpecialAttack", "UltimateAttack"]:
			# Only go to Hit state if not currently attacking
			character.state_machine.change_state("Hit")
		# If they ARE attacking, they continue their attack (attack priority)
		# NO WHITE FLASH here either
	
	return not blocked

# NEW: Apply brief stun to attacker when they hit a blocking opponent
func apply_block_stun():
	print("CombatComponent: Applying block stun to attacker")
	
	# Longer freeze - prevent input for more time
	var stun_duration = 1.0  # 400ms stun (about 24 frames at 60fps)
	
	# Create a timer to handle the stun
	var stun_timer = Timer.new()
	character.add_child(stun_timer)
	stun_timer.wait_time = stun_duration
	stun_timer.one_shot = true
	
	# Set a flag on the character to indicate they're stunned
	character.set("is_block_stunned", true)
	
	# Stronger knockback - push attacker away
	character.velocity.x = 0  # Stop current movement
	var knockback_force = -150.0 if character.player_number == 1 else 150.0
	
	# Apply knockback using a tween for smooth motion
	var tween = create_tween()
	var knockback_distance = -30.0 if character.player_number == 1 else 30.0
	var start_pos = character.global_position.x
	var target_pos = start_pos + knockback_distance
	
	# Knockback animation (quick push back, then gradual stop)
	tween.tween_method(func(pos_x): character.global_position.x = pos_x, start_pos, target_pos, 0.2)
	tween.tween_callback(func(): character.velocity.x = 0)  # Stop any residual movement
	
	# End stun after timer expires
	stun_timer.timeout.connect(func():
		if character.has_method("set") and character.get("is_block_stunned"):
			character.set("is_block_stunned", false)
		character.velocity.x = 0  # Ensure stopped
		stun_timer.queue_free()
		print("CombatComponent: Block stun ended")
	)
	
	stun_timer.start()

# NEW: Play hit sound with random pitch variation
func play_hit_sound_with_pitch_variation():
	if not character.character_data.hit_sound or not character.audio_player:
		return
	
	# Random pitch variation between 0.8 and 1.2 (±20%)
	var pitch_variation = randf_range(0.8, 1.2)
	
	# Set the pitch
	character.audio_player.pitch_scale = pitch_variation
	
	# Play the sound
	character.play_sound(character.character_data.hit_sound)
	
	# Reset pitch back to normal after playing (optional, but good practice)
	# We'll reset it after a short delay to avoid cutting off the current sound
	var timer = Timer.new()
	character.add_child(timer)
	timer.wait_time = 0.1
	timer.one_shot = true
	timer.timeout.connect(func(): 
		if character.audio_player:
			character.audio_player.pitch_scale = 1.0
		timer.queue_free()
	)
	timer.start()

func register_hit():
	character.combo_count += 1
	character.combo_timer = character.character_data.combo_timeout
	character.emit_signal("combo_changed", character.combo_count)
	EventBus.emit_signal("combo_changed", character, character.combo_count)
	
	charge_special_meter(character.character_data.special_meter_gain_per_hit)
	
	var combo_bonus = character.combo_count * 2.0
	charge_ultimate_meter(combo_bonus)

func charge_special_meter(amount: float):
	character.special_meter += amount
	character.special_meter = min(character.special_meter, character.character_data.special_meter_max)
	character.emit_signal("special_meter_changed", character.special_meter)
	EventBus.emit_signal("special_meter_changed", character, character.special_meter)

func charge_ultimate_meter(amount: float):
	character.ultimate_meter += amount
	character.ultimate_meter = min(character.ultimate_meter, character.character_data.ultimate_meter_max)
	character.emit_signal("ultimate_meter_changed", character.ultimate_meter)
	EventBus.emit_signal("ultimate_meter_changed", character, character.ultimate_meter)
