# AttackState.gd
extends State
class_name AttackState

var attack_timer: float = 0.0
var attack_hit_applied: bool = false
var attack_type: String = ""

func enter():
	attack_timer = 0.0
	attack_hit_applied = false
	character.velocity.x = 0
	
	# Set higher z_index when attacking
	if character.sprite:
		character.sprite.z_index = 5
	
	var animation_name = get_animation_name()
	if character.sprite and character.sprite.sprite_frames and character.sprite.sprite_frames.has_animation(animation_name):
		character.play_animation(animation_name)
	else:
		# If animation doesn't exist, go back to idle immediately
		state_machine.change_state("Idle")
		return
	
	# Play attack sound with pitch variation for light and heavy attacks
	play_attack_sound_with_pitch()
	
	var attack_area = character.get_node("AttackArea")
	attack_area.monitoring = true
	
	EventBus.emit_signal("attack_started", character, attack_type)
	
	print("Started attack: ", attack_type, " with duration: ", get_attack_duration())

func update(delta):
	attack_timer += delta
	
	var hit_timing = get_attack_duration()
	if attack_timer >= hit_timing and not attack_hit_applied:
		apply_attack_hit()
		attack_hit_applied = true
		print("Applied hit for attack: ", attack_type)

func _on_animation_finished(animation_name: String):
	# Check if this is our attack animation
	if animation_name == get_animation_name():
		print("Attack animation finished: ", animation_name)
		state_machine.change_state("Idle")

func exit():
	print("Exiting attack state: ", attack_type)
	# Reset z_index when attack finishes
	if character.sprite:
		character.sprite.z_index = 0
	
	var attack_area = character.get_node("AttackArea")
	attack_area.monitoring = false

# NEW: Play attack sound with pitch variation for light/heavy attacks
func play_attack_sound_with_pitch():
	var attack_sound = get_attack_sound()
	if not attack_sound or not character.audio_player:
		return
	
	# Add pitch variation only for light and heavy attacks
	if attack_type == "light" or attack_type == "heavy":
		# Random pitch variation between 0.9 and 1.1 (±10% for attack sounds)
		var pitch_variation = randf_range(0.9, 1.1)
		character.audio_player.pitch_scale = pitch_variation
		
		# Play the sound
		character.play_sound(attack_sound)
		
		# Reset pitch back to normal after playing
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
	else:
		# No pitch variation for specials, ultimates, or other attack types
		character.play_sound(attack_sound)

func get_animation_name() -> String:
	return ""  # Override in subclasses

func get_attack_sound() -> AudioStream:
	return null  # Override in subclasses

func get_attack_duration() -> float:
	return 0.0  # Override in subclasses

func apply_attack_hit():
	# Use character's existing apply_attack_hit logic
	character.apply_attack_hit()
