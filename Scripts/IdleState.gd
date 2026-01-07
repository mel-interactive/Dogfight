# IdleState.gd - FIXED to use VisualComponent
extends State
class_name IdleState

func enter():
	character.velocity.x = 0
	character.movement_direction = 0.0
	
	# FIXED: Use visual_component instead of direct sprite access
	if character.visual_component:
		if character.visual_component.has_animation("idle") and character.visual_component.get_current_animation() != "idle":
			character.play_animation("idle")
		elif not character.visual_component.has_animation("idle"):
			if character.visual_component.get_current_animation() != "":
				character.visual_component.stop_animation()

func physics_update(_delta):
	if abs(character.velocity.x) > 10:
		state_machine.change_state("Moving")
