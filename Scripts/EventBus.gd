# EventBus.gd - Add as Autoload singleton in Project Settings
extends Node

# Character events
signal character_health_changed(character: BaseCharacter, new_health: int)
signal character_defeated(character: BaseCharacter)
signal character_took_damage(character: BaseCharacter, damage: int, was_blocked: bool)

# Meter events  
signal special_meter_changed(character: BaseCharacter, new_value: float)
signal ultimate_meter_changed(character: BaseCharacter, new_value: float)

# Combat events
signal attack_started(character: BaseCharacter, attack_type: String)
signal attack_hit(attacker: BaseCharacter, target: BaseCharacter, damage: int, attack_type: String)
signal attack_blocked(attacker: BaseCharacter, target: BaseCharacter, attack_type: String)
signal combo_changed(character: BaseCharacter, combo_count: int)

# Animation events
signal animation_started(character: BaseCharacter, animation_name: String)
signal animation_finished(character: BaseCharacter, animation_name: String)

# Visual effects
signal screen_shake_requested(intensity: float, duration: float)
signal character_hit_shake(character: BaseCharacter)
