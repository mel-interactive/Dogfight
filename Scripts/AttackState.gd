
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
	
	character.play_sound(get_attack_sound())
	
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

func get_animation_name() -> String:
	return ""  # Override in subclasses

func get_attack_sound() -> AudioStream:
	return null  # Override in subclasses

func get_attack_duration() -> float:
	return 0.0  # Override in subclasses

func apply_attack_hit():
	# Use character's existing apply_attack_hit logic
	character.apply_attack_hit()
