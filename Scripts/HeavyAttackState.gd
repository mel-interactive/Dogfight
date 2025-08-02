
# HeavyAttackState.gd  
extends AttackState
class_name HeavyAttackState

func _ready():
	attack_type = "heavy"

func get_animation_name() -> String:
	return "heavy_attack"

func get_attack_sound() -> AudioStream:
	return character.character_data.heavy_attack_sound

func get_attack_duration() -> float:
	return character.character_data.heavy_attack_duration
