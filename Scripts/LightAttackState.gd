# LightAttackState.gd
extends AttackState
class_name LightAttackState

func _ready():
	attack_type = "light"

func get_animation_name() -> String:
	return "light_attack"

func get_attack_sound() -> AudioStream:
	return character.character_data.light_attack_sound

func get_attack_duration() -> float:
	return character.character_data.light_attack_duration
