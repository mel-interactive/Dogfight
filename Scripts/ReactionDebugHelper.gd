# ReactionDebugHelper.gd - Helper script to debug reaction issues
# Attach this to a node in your scene or run parts of it in the debugger

extends Node

func debug_reaction_setup(character: BaseCharacter, attacking_character_id: String, attack_type: String):
	print("=== REACTION DEBUG START ===")
	
	# Check if character exists
	if not character:
		print("ERROR: Character is null!")
		return
	
	print("Character: ", character.character_data.character_name if character.character_data else "NO CHARACTER DATA")
	print("Character ID: ", character.character_data.character_id if character.character_data else "NO ID")
	
	# Check if character data exists
	if not character.character_data:
		print("ERROR: Character has no character_data!")
		return
	
	# Check if reaction_data array exists and has content
	print("Reaction data array size: ", character.character_data.reaction_data.size())
	
	if character.character_data.reaction_data.size() == 0:
		print("ERROR: No reactions in reaction_data array!")
		return
	
	# List all available reactions
	print("Available reactions:")
	for i in range(character.character_data.reaction_data.size()):
		var reaction = character.character_data.reaction_data[i]
		if reaction:
			print("  [", i, "] Target: '", reaction.target_character_id, "' vs Attacker: '", reaction.attacking_character_id, "' Type: '", reaction.attack_type, "'")
		else:
			print("  [", i, "] NULL REACTION!")
	
	# Check for specific reaction
	print("Looking for reaction: Target='", character.character_data.character_id, "' vs Attacker='", attacking_character_id, "' Type='", attack_type, "'")
	
	var found_reaction = character.character_data.get_reaction_for_attack(attacking_character_id, attack_type)
	if found_reaction:
		print("SUCCESS: Found matching reaction!")
		print("  Reaction animation: ", found_reaction.reaction_animation)
		print("  Additional animations: ", found_reaction.additional_animations.size())
		print("  Reaction sound: ", found_reaction.reaction_sound)
	else:
		print("ERROR: No matching reaction found!")
		
		# Check for close matches
		print("Checking for similar reactions:")
		for reaction in character.character_data.reaction_data:
			if reaction.attacking_character_id == attacking_character_id:
				print("  Found reaction for same attacker but different type: '", reaction.attack_type, "' (looking for '", attack_type, "')")
			if reaction.attack_type == attack_type:
				print("  Found reaction for same type but different attacker: '", reaction.attacking_character_id, "' (looking for '", attacking_character_id, "')")
	
	# Check if reaction component exists
	if not character.reaction_component:
		print("ERROR: Character has no reaction_component!")
		return
	else:
		print("SUCCESS: Reaction component exists")
	
	print("=== REACTION DEBUG END ===")

func debug_combat_flow(attacker: BaseCharacter, defender: BaseCharacter):
	print("=== COMBAT DEBUG START ===")
	
	if not attacker or not defender:
		print("ERROR: Attacker or defender is null!")
		return
	
	print("Attacker: ", attacker.character_data.character_name if attacker.character_data else "NO DATA")
	print("Defender: ", defender.character_data.character_name if defender.character_data else "NO DATA")
	
	# Check current state
	print("Attacker state: ", attacker.state_machine.get_current_state_name() if attacker.state_machine else "NO STATE MACHINE")
	print("Defender state: ", defender.state_machine.get_current_state_name() if defender.state_machine else "NO STATE MACHINE")
	
	# Check if characters are in range
	if attacker.combat_component:
		var in_special_range = attacker.combat_component.is_opponent_in_attack_range(attacker.character_data.special_attack_range)
		var in_ultimate_range = attacker.combat_component.is_opponent_in_attack_range(attacker.character_data.ultimate_attack_range)
		print("In special range: ", in_special_range)
		print("In ultimate range: ", in_ultimate_range)
	else:
		print("ERROR: Attacker has no combat_component!")
	
	# Check meters
	print("Attacker special meter: ", attacker.special_meter, "/", attacker.character_data.special_meter_max if attacker.character_data else "NO DATA")
	print("Attacker ultimate meter: ", attacker.ultimate_meter, "/", attacker.character_data.ultimate_meter_max if attacker.character_data else "NO DATA")
	
	print("=== COMBAT DEBUG END ===")

# Quick test function you can call from anywhere
func quick_reaction_test():
	# Find the characters in the scene
	var characters = get_tree().get_nodes_in_group("characters")  # Assuming you add characters to a group
	
	if characters.size() < 2:
		# Try to find them by name or type
		characters = []
		for node in get_tree().current_scene.get_children():
			if node is BaseCharacter:
				characters.append(node)
	
	if characters.size() < 2:
		print("ERROR: Cannot find 2 characters to test!")
		return
	
	var char1 = characters[0] as BaseCharacter
	var char2 = characters[1] as BaseCharacter
	
	print("Testing reactions between: ", char1.character_data.character_name, " and ", char2.character_data.character_name)
	
	debug_reaction_setup(char1, char2.character_data.character_id, "special_attack")
	debug_reaction_setup(char2, char1.character_data.character_id, "special_attack")

# Call this during a special attack to see what's happening
func debug_special_attack_trigger(attacker: BaseCharacter):
	print("=== SPECIAL ATTACK DEBUG ===")
	
	if not attacker:
		print("ERROR: No attacker!")
		return
	
	print("Attacker: ", attacker.character_data.character_name)
	print("Attacker ID: ", attacker.character_data.character_id)
	print("Current state: ", attacker.state_machine.get_current_state_name())
	
	if not attacker.opponent:
		print("ERROR: No opponent set!")
		return
	
	print("Opponent: ", attacker.opponent.character_data.character_name)
	print("Opponent ID: ", attacker.opponent.character_data.character_id)
	
	# Check if opponent has reaction for this attacker
	debug_reaction_setup(attacker.opponent, attacker.character_data.character_id, "special_attack")
