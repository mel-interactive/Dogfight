# CombatComponent.gd
extends Node
class_name CombatComponent

var character: BaseCharacter

func _ready():
	character = get_parent()

func _process(delta):
	# Combo timer
	if character.combo_count > 0:
		character.combo_timer -= delta
		if character.combo_timer <= 0:
			character.combo_count = 0
			character.emit_signal("combo_changed", character.combo_count)
			EventBus.emit_signal("combo_changed", character, character.combo_count)
	
	# Charge ultimate meter
	charge_ultimate_meter(character.character_data.ultimate_meter_gain_per_second * delta)

func apply_attack_hit():
	if not character.opponent:
		return
	
	var damage: int = 0
	var attack_range: float = 0
	var ignore_block: bool = false
	var attack_type: String = ""
	
	var state_name = character.state_machine.get_current_state_name()
	match state_name:
		"LightAttack":
			damage = character.character_data.light_attack_damage
			attack_range = character.character_data.light_attack_range
			ignore_block = false
			attack_type = "light"
		"HeavyAttack":
			damage = character.character_data.heavy_attack_damage
			attack_range = character.character_data.heavy_attack_range
			ignore_block = false
			attack_type = "heavy"
		"SpecialAttack":
			damage = character.character_data.special_attack_damage
			attack_range = character.character_data.special_attack_range
			ignore_block = true
			attack_type = "special"
		"UltimateAttack":
			damage = character.character_data.ultimate_attack_damage
			attack_range = character.character_data.ultimate_attack_range
			ignore_block = true
			attack_type = "ultimate"
	
	# Check if opponent is in range
	if is_opponent_in_attack_range(attack_range):
		if ignore_block:
			# Special/Ultimate attacks ignore blocking
			var damage_taken = character.opponent.take_damage(damage, true)
			if damage_taken:
				register_hit()
				EventBus.emit_signal("attack_hit", character, character.opponent, damage, attack_type)
		else:
			# Normal attacks check for blocking
			var is_blocked = character.opponent.is_blocking()
			if is_blocked:
				# Play block sound and shake
				character.opponent.play_sound(character.opponent.character_data.block_sound)
				character.opponent.visual_component.do_simple_shake()
				EventBus.emit_signal("attack_blocked", character, character.opponent, attack_type)
			else:
				# Full damage
				var damage_taken = character.opponent.take_damage(damage, false)
				if damage_taken:
					register_hit()
					EventBus.emit_signal("attack_hit", character, character.opponent, damage, attack_type)

func is_opponent_in_attack_range(attack_range: float) -> bool:
	if not character.opponent:
		return false
	
	var my_x = character.global_position.x
	var opponent_x = character.opponent.global_position.x
	
	if character.player_number == 1:
		return opponent_x >= my_x and opponent_x <= (my_x + attack_range)
	else:
		return opponent_x <= my_x and opponent_x >= (my_x - attack_range)

func take_damage(damage_amount: int, ignore_block: bool) -> bool:
	# If ignore_block is true, skip all blocking logic
	if ignore_block:
		character.current_health -= damage_amount
		character.current_health = max(0, character.current_health)
		
		character.emit_signal("health_changed", character.current_health)
		EventBus.emit_signal("character_health_changed", character, character.current_health)
		
		if character.current_health <= 0:
			character.state_machine.change_state("Defeat")
		else:
			character.state_machine.change_state("Hit")
			character.play_sound(character.character_data.hit_sound)
			# NO WHITE FLASH for ignore_block attacks (specials/ultimates)
		
		return true  # Damage was taken
	
	# Normal damage with blocking check
	var blocked = character.is_blocking()
	
	if blocked:
		# Convert to int to avoid narrowing conversion warning
		damage_amount = int(damage_amount * 0.2)
		character.play_sound(character.character_data.block_sound)
		# WHITE FLASH only happens when blocking
		character.visual_component.do_simple_shake()
	else:
		character.play_sound(character.character_data.hit_sound)
		# NO WHITE FLASH for normal hits
	
	character.current_health -= damage_amount
	character.current_health = max(0, character.current_health)
	
	character.emit_signal("health_changed", character.current_health)
	EventBus.emit_signal("character_health_changed", character, character.current_health)
	
	if character.current_health <= 0:
		character.state_machine.change_state("Defeat")
	elif not blocked:
		character.state_machine.change_state("Hit")
		# NO WHITE FLASH here either
	
	return not blocked

func register_hit():
	character.combo_count += 1
	character.combo_timer = character.character_data.combo_timeout
	character.emit_signal("combo_changed", character.combo_count)
	EventBus.emit_signal("combo_changed", character, character.combo_count)
	
	charge_special_meter(character.character_data.special_meter_gain_per_hit)
	
	var combo_bonus = character.combo_count * 2.0
	charge_ultimate_meter(combo_bonus)

func charge_special_meter(amount: float):
	character.special_meter += amount
	character.special_meter = min(character.special_meter, character.character_data.special_meter_max)
	character.emit_signal("special_meter_changed", character.special_meter)
	EventBus.emit_signal("special_meter_changed", character, character.special_meter)

func charge_ultimate_meter(amount: float):
	character.ultimate_meter += amount
	character.ultimate_meter = min(character.ultimate_meter, character.character_data.ultimate_meter_max)
	character.emit_signal("ultimate_meter_changed", character.ultimate_meter)
	EventBus.emit_signal("ultimate_meter_changed", character, character.ultimate_meter)
