# BlockingState.gd - FIXED to use VisualComponent
extends State
class_name BlockingState

func enter():
	# FIXED: Use visual_component instead of direct sprite access
	if character.visual_component and character.visual_component.has_animation("block"):
		character.play_animation("block")
