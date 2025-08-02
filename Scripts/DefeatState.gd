
# DefeatState.gd
extends State
class_name DefeatState

func enter():
	if character.sprite and character.sprite.sprite_frames and character.sprite.sprite_frames.has_animation("defeat"):
		character.play_animation("defeat")
	character.play_sound(character.character_data.defeat_sound)
	EventBus.emit_signal("character_defeated", character)
