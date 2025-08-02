extends State
class_name MovingState

func enter():
	character.movement_direction = sign(character.velocity.x)
	var target_anim = character.get_movement_animation()
	if character.sprite and character.sprite.sprite_frames and character.sprite.sprite_frames.has_animation(target_anim):
		if character.sprite.animation != target_anim:
			character.play_animation(target_anim)

func physics_update(delta):
	if abs(character.velocity.x) <= 10:
		state_machine.change_state("Idle")
	else:
		character.movement_direction = sign(character.velocity.x)
		var target_anim = character.get_movement_animation()
		if character.sprite and character.sprite.sprite_frames and character.sprite.sprite_frames.has_animation(target_anim):
			if character.sprite.animation != target_anim:
				character.play_animation(target_anim)
