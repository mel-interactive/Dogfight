extends State
class_name IdleState

func enter():
	character.velocity.x = 0
	character.movement_direction = 0.0
	if character.sprite and character.sprite.sprite_frames:
		if character.sprite.sprite_frames.has_animation("idle") and character.sprite.animation != "idle":
			character.play_animation("idle")
		elif not character.sprite.sprite_frames.has_animation("idle"):
			if character.sprite.animation != "":
				character.sprite.stop()

func physics_update(_delta):
	if abs(character.velocity.x) > 10:
		state_machine.change_state("Moving")
