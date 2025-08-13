# ReactionComponent.gd - Component for handling character-specific reactions
extends Node
class_name ReactionComponent

var character: BaseCharacter
var current_reaction: ReactionData = null

# Custom reaction sprite for playing specific reactions
var reaction_sprite: AnimatedSprite2D
var reaction_custom_sprites: Array[AnimatedSprite2D] = []

func _ready():
	character = get_parent()
	setup_reaction_sprites()

func setup_reaction_sprites():
	# Create reaction sprite for character-specific reactions
	reaction_sprite = AnimatedSprite2D.new()
	reaction_sprite.name = "ReactionSprite"
	reaction_sprite.visible = false
	reaction_sprite.z_index = 5  # Above normal sprite but below custom animations
	character.add_child(reaction_sprite)
	reaction_sprite.connect("animation_finished", _on_reaction_animation_finished)

func play_reaction_to_attack(attacking_character: BaseCharacter, attack_type: String) -> bool:
	print("ReactionComponent: play_reaction_to_attack called")
	print("  My character: ", character.character_data.character_name if character.character_data else "NO DATA")
	print("  Attacking character: ", attacking_character.character_data.character_name if attacking_character and attacking_character.character_data else "NO DATA")
	print("  Attack type: ", attack_type)
	
	if not attacking_character or not attacking_character.character_data:
		print("  FAILED: No attacking character or character data")
		return false
	
	# Find matching reaction in our character data
	var reaction = find_reaction_for_attack(attacking_character.character_data.character_id, attack_type)
	if not reaction:
		print("  FAILED: No matching reaction found")
		return false
	
	print("  SUCCESS: Found matching reaction!")
	print("Playing reaction: ", character.character_data.character_name, " reacting to ", attacking_character.character_data.character_name, "'s ", attack_type)
	
	current_reaction = reaction
	
	# Setup and play the reaction animation
	setup_reaction_animation(reaction)
	play_reaction_animation(reaction)
	
	# Play reaction sound if available
	if reaction.reaction_sound:
		character.play_sound(reaction.reaction_sound)
	
	return true

func find_reaction_for_attack(attacking_character_id: String, attack_type: String) -> ReactionData:
	print("  ReactionComponent: Looking for reaction")
	print("    Target ID (me): ", character.character_data.character_id if character.character_data else "NO ID")
	print("    Attacking ID: ", attacking_character_id)
	print("    Attack type: ", attack_type)
	print("    Available reactions: ", character.character_data.reaction_data.size() if character.character_data else "NO DATA")
	
	if not character.character_data:
		print("    FAILED: No character data")
		return null
	
	# Look through all reaction data in our character data
	for i in range(character.character_data.reaction_data.size()):
		var reaction = character.character_data.reaction_data[i]
		print("    Checking reaction [", i, "]: target='", reaction.target_character_id, "' attacker='", reaction.attacking_character_id, "' type='", reaction.attack_type, "'")
		
		if reaction.attacking_character_id == attacking_character_id and reaction.attack_type == attack_type:
			print("    MATCH FOUND!")
			return reaction
	
	print("    NO MATCH FOUND")
	return null

func setup_reaction_animation(reaction: ReactionData):
	if not reaction.reaction_animation:
		return
	
	# Setup the reaction sprite
	reaction_sprite.sprite_frames = reaction.reaction_animation
	reaction_sprite.scale = character.character_data.base_scale * reaction.reaction_scale
	
	# Handle flipping
	if reaction.flip_with_player:
		reaction_sprite.flip_h = (character.player_number == 1)
	else:
		reaction_sprite.flip_h = false
	
	# Position the reaction sprite
	position_reaction_sprite(reaction)
	
	# Setup custom animations for this reaction
	setup_reaction_custom_animations(reaction)

func position_reaction_sprite(reaction: ReactionData):
	# Position relative to character
	reaction_sprite.global_position = character.global_position
	
	# Apply offset (flip X for player 1)
	var offset_to_use = reaction.reaction_offset
	if character.player_number == 1:
		offset_to_use.x = -offset_to_use.x
	
	reaction_sprite.global_position += offset_to_use
	
	# Set proper anchoring
	if reaction_sprite.sprite_frames:
		var available_animations = reaction_sprite.sprite_frames.get_animation_names()
		if available_animations.size() > 0:
			var anim_name = available_animations[0]
			var current_frame = reaction_sprite.sprite_frames.get_frame_texture(anim_name, 0)
			if current_frame:
				var frame_width = current_frame.get_width()
				var frame_height = current_frame.get_height()
				
				reaction_sprite.offset.y = -frame_height / 2.0
				
				if character.player_number == 1:
					reaction_sprite.offset.x = frame_width / 2.0
				else:
					reaction_sprite.offset.x = -frame_width / 2.0

func setup_reaction_custom_animations(reaction: ReactionData):
	# Clean up existing reaction custom sprites
	for sprite in reaction_custom_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	reaction_custom_sprites.clear()
	
	# Create sprites for additional animations
	for i in range(reaction.additional_animations.size()):
		var additional_anim = reaction.additional_animations[i]
		if not additional_anim:
			continue
		
		var custom_sprite = AnimatedSprite2D.new()
		custom_sprite.name = "ReactionAdditionalSprite" + str(i)
		custom_sprite.visible = false
		custom_sprite.z_index = 15
		character.add_child(custom_sprite)
		
		custom_sprite.sprite_frames = additional_anim
		custom_sprite.connect("animation_finished", _on_reaction_custom_animation_finished.bind(i))
		
		reaction_custom_sprites.append(custom_sprite)

func play_reaction_animation(reaction: ReactionData):
	if not reaction.reaction_animation:
		return
	
	# Get first available animation
	var available_animations = reaction_sprite.sprite_frames.get_animation_names()
	if available_animations.size() == 0:
		return
	
	var anim_name = available_animations[0]
	
	# HIDE THE MAIN SPRITE while reaction plays to avoid doubling
	if character.sprite:
		character.sprite.visible = false
	
	# Play the reaction animation
	reaction_sprite.play(anim_name)
	reaction_sprite.visible = true
	
	# Play additional animations
	play_additional_animations(reaction)
	
	# If reaction has duration override, use it
	if reaction.duration_override > 0:
		var timer = Timer.new()
		character.add_child(timer)
		timer.wait_time = reaction.duration_override
		timer.one_shot = true
		timer.timeout.connect(_force_reaction_end)
		timer.timeout.connect(timer.queue_free)
		timer.start()

func play_additional_animations(reaction: ReactionData):
	for i in range(min(reaction.additional_animations.size(), reaction_custom_sprites.size())):
		var additional_anim = reaction.additional_animations[i]
		var custom_sprite = reaction_custom_sprites[i]
		
		if not custom_sprite or not additional_anim:
			continue
		
		# Get first available animation
		var available_animations = additional_anim.get_animation_names()
		if available_animations.size() == 0:
			continue
		
		var anim_name = available_animations[0]
		
		# Apply scale (use provided scale or default to 1,1)
		var scale_to_use = Vector2(1.0, 1.0)
		if i < reaction.additional_animation_scales.size():
			scale_to_use = reaction.additional_animation_scales[i]
		custom_sprite.scale = character.character_data.base_scale * scale_to_use
		
		# Handle flipping (use provided flip or default to true)
		var flip_with_player = true
		if i < reaction.additional_animation_flips.size():
			flip_with_player = reaction.additional_animation_flips[i]
		
		if flip_with_player:
			custom_sprite.flip_h = (character.player_number == 1)
		else:
			custom_sprite.flip_h = false
		
		# Position the additional animation
		position_additional_animation(custom_sprite, reaction, i)
		
		# Play the animation
		custom_sprite.play(anim_name)
		custom_sprite.visible = true

func position_additional_animation(custom_sprite: AnimatedSprite2D, reaction: ReactionData, index: int):
	# Position relative to character
	custom_sprite.global_position = character.global_position
	
	# Reset offset to center the sprite first
	custom_sprite.offset = Vector2.ZERO
	
	# Apply offset (use provided offset or default to 0,0)
	var offset_to_use = Vector2(0.0, 0.0)
	if index < reaction.additional_animation_offsets.size():
		offset_to_use = reaction.additional_animation_offsets[index]
	
	# ALWAYS flip X offset for player 1 (regardless of sprite flip setting)
	if character.player_number == 1:
		offset_to_use.x = -offset_to_use.x
	
	custom_sprite.global_position += offset_to_use

func position_reaction_custom_animation(custom_sprite: AnimatedSprite2D, custom_anim: CustomAnimation):
	if custom_anim.anchored_to_player:
		# Position relative to the character
		custom_sprite.global_position = character.global_position
		
		# Reset offset to center the sprite first
		custom_sprite.offset = Vector2.ZERO
		
		# Add offset - flip X for player 1
		var offset_to_use = custom_anim.position_offset
		if character.player_number == 1:
			offset_to_use.x = -offset_to_use.x
		
		custom_sprite.global_position += offset_to_use
	else:
		# Position at screen center
		var viewport_size = character.get_viewport().get_visible_rect().size
		custom_sprite.global_position = Vector2(viewport_size.x / 2.0, viewport_size.y / 2.0)
		
		custom_sprite.offset = Vector2.ZERO
		custom_sprite.global_position += custom_anim.position_offset

func stop_reaction():
	if reaction_sprite:
		reaction_sprite.visible = false
		reaction_sprite.stop()
	
	# RESTORE THE MAIN SPRITE visibility
	if character.sprite:
		character.sprite.visible = true
	
	# Hide custom animations
	for sprite in reaction_custom_sprites:
		if is_instance_valid(sprite):
			sprite.visible = false
			sprite.stop()
	
	current_reaction = null

func _on_reaction_animation_finished():
	stop_reaction()

func _on_reaction_custom_animation_finished(sprite_index: int):
	if sprite_index < reaction_custom_sprites.size():
		var custom_sprite = reaction_custom_sprites[sprite_index]
		custom_sprite.visible = false

func _force_reaction_end():
	stop_reaction()

func has_reaction_for_attack(attacking_character_id: String, attack_type: String) -> bool:
	return find_reaction_for_attack(attacking_character_id, attack_type) != null
