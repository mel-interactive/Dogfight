# EntranceState.gd 
extends State
class_name EntranceState

func enter():
	print("EntranceState: Character ", character.player_number, " entering entrance state")
	
	# FORCE stop any movement immediately
	character.velocity = Vector2.ZERO
	character.movement_direction = 0.0
	
	# Make sure character is at their spawn position
	var spawn_pos = character.get_spawn_position()
	character.global_position = spawn_pos
	
	# Play entrance animation if it exists
	if character.character_data.has_base_animation("entrance"):
		character.play_animation("entrance")
		print("EntranceState: Playing entrance animation for player ", character.player_number)
	else:
		# If no entrance animation, just play idle and immediately finish
		character.play_animation("idle")
		print("EntranceState: No entrance animation, using idle for player ", character.player_number)
		# Emit the entrance finished signal after a short delay
		await character.get_tree().create_timer(0.1).timeout
		EventBus.emit_signal("character_entrance_finished", character)

func _on_animation_finished(animation_name: String):
	print("EntranceState: Animation finished: ", animation_name, " for player ", character.player_number)
	if animation_name == "entrance":
		# Entrance animation completed
		EventBus.emit_signal("character_entrance_finished", character)
		state_machine.change_state("Idle")

# Override physics_process to ensure no movement during entrance
func physics_process(_delta: float):
	# Force velocity to zero during entrance
	character.velocity = Vector2.ZERO
