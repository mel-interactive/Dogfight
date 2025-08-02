
# BlockingState.gd
extends State
class_name BlockingState

func enter():
	if character.sprite and character.sprite.sprite_frames and character.sprite.sprite_frames.has_animation("block"):
		character.play_animation("block")
	character.play_sound(character.character_data.block_sound)
