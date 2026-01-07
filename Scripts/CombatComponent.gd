# CombatComponent.gd
extends Node
class_name CombatComponent

var character: BaseCharacter

func _ready():
	character = get_parent()

func apply_attack_hit():
	if not character.opponent:
		return
	
	var damage = get_attack_damage()
	var ignore_block = is_unblockable_attack()
	
	# Try to damage opponent
	var hit_successful = character.opponent.take_damage(damage, ignore_block)
	
	if hit_successful:
		# Increment combo on successful hit
		register_hit()

func get_attack_damage() -> int:
	var state_name = character.state_machine.get_current_state_name()
	
	match state_name:
		"LightAttack":
			return character.character_data.light_attack_damage
		"HeavyAttack":
			return character.character_data.heavy_attack_damage
		"SpecialAttack":
			return character.character_data.special_attack_damage
		"UltimateAttack":
			return character.character_data.ultimate_attack_damage
		_:
			return 0

func is_unblockable_attack() -> bool:
	var state_name = character.state_machine.get_current_state_name()
	return state_name in ["SpecialAttack", "UltimateAttack"]

func take_damage(damage_amount: int, ignore_block: bool) -> bool:
	# Check if blocking (and attack is blockable)
	if character.is_blocking() and not ignore_block:
		print(character.character_data.character_name, " blocked the attack!")
		# Take reduced damage when blocking
		var blocked_damage = max(1, damage_amount / 4)
		character.current_health -= blocked_damage
		character.emit_signal("health_changed", character.current_health)
		
		# Visual feedback
		character.do_simple_shake()
		
		# Reset attacker's combo (blocked attack breaks combo)
		if character.opponent:
			character.opponent.combo_count = 0
			character.opponent.emit_signal("combo_changed", 0)
		
		return false  # Attack was blocked
	else:
		# Take full damage
		character.current_health -= damage_amount
		character.emit_signal("health_changed", character.current_health)
		
		# Play hit animation
		character.state_machine.change_state("Hit")
		character.do_simple_shake()
		
		# Check for defeat
		if character.current_health <= 0:
			character.current_health = 0
			character.state_machine.change_state("Defeat")
		
		# Reset this character's combo (getting hit breaks your combo)
		character.combo_count = 0
		character.emit_signal("combo_changed", 0)
		
		return true  # Attack hit successfully

func register_hit():
	# Increment combo
	character.combo_count += 1
	character.combo_timer = 2.0  # 2 second combo window
	character.emit_signal("combo_changed", character.combo_count)
	
	print(character.character_data.character_name, " combo: ", character.combo_count)
	
	# Charge meters based on combo
	var meter_gain = 10.0 + (character.combo_count * 2.0)  # More meter for longer combos
	charge_special_meter(meter_gain)
	charge_ultimate_meter(meter_gain * 0.5)

func charge_special_meter(amount: float):
	character.special_meter = min(character.special_meter + amount, character.character_data.special_meter_max)
	character.emit_signal("special_meter_changed", character.special_meter)

func charge_ultimate_meter(amount: float):
	character.ultimate_meter = min(character.ultimate_meter + amount, character.character_data.ultimate_meter_max)
	character.emit_signal("ultimate_meter_changed", character.ultimate_meter)

func is_opponent_in_attack_range(attack_range: float) -> bool:
	if not character.opponent:
		return false
	
	var distance = abs(character.global_position.x - character.opponent.global_position.x)
	return distance <= attack_range

# NEW: Trigger character-specific reactions
func trigger_attack_reaction(attack_type: String):
	if not character.opponent:
		return
	
	# Try to play a character-specific reaction on the opponent
	var reaction_played = character.opponent.play_reaction_to_attack(character, attack_type)
	
	if reaction_played:
		print("Reaction triggered: ", character.opponent.character_data.character_name, " reacting to ", character.character_data.character_name, "'s ", attack_type)
	else:
		print("No reaction found for: ", character.opponent.character_data.character_name, " vs ", character.character_data.character_name, "'s ", attack_type)
