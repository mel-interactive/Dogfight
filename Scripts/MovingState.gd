# MovingState.gd - FIXED to use VisualComponent
extends State
class_name MovingState

func enter():
	character.movement_direction = sign(character.velocity.x)
	var target_anim = character.get_movement_animation()
	
	# FIXED: Use visual_component
	if character.visual_component and character.visual_component.has_animation(target_anim):
		if character.visual_component.get_current_animation() != target_anim:
			character.play_animation(target_anim)

func physics_update(_delta):
	if abs(character.velocity.x) <= 10:
		state_machine.change_state("Idle")
	else:
		character.movement_direction = sign(character.velocity.x)
		var target_anim = character.get_movement_animation()
		
		# FIXED: Use visual_component
		if character.visual_component and character.visual_component.has_animation(target_anim):
			if character.visual_component.get_current_animation() != target_anim:
				character.play_animation(target_anim)
