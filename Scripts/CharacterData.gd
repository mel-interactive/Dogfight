# CharacterData.gd - Enhanced with reaction system
extends Resource
class_name CharacterData

# Basic info
@export var character_id: String = "default"
@export var character_name: String = "Default Fighter"
@export var description: String = "A basic fighter"

# Visual properties
@export var sprite_texture: Texture2D
@export var color: Color = Color.WHITE
@export var base_scale: Vector2 = Vector2(1.0, 1.0)

# Stats
@export var max_health: int = 100
@export var move_speed: float = 300.0

# Attack properties
@export var light_attack_damage: int = 5
@export var heavy_attack_damage: int = 15
@export var special_attack_damage: int = 25
@export var ultimate_attack_damage: int = 40

# Attack ranges
@export_group("Attack Ranges")
@export var light_attack_range: float = 80.0
@export var heavy_attack_range: float = 100.0
@export var special_attack_range: float = 120.0
@export var ultimate_attack_range: float = 150.0

# Meter settings
@export var special_meter_max: float = 100.0
@export var ultimate_meter_max: float = 100.0
@export var special_meter_gain_per_hit: float = 20.0
@export var ultimate_meter_gain_per_second: float = 5.0

# Combo settings
@export var combo_timeout: float = 1.5

# Attack timing
@export var light_attack_duration: float = 0.2
@export var heavy_attack_duration: float = 0.5
@export var special_attack_duration: float = 0.7
@export var ultimate_attack_duration: float = 1.0
@export var hit_stun_duration: float = 0.3

# NEW REACTION SYSTEM
@export_group("Character Reactions")
@export var reaction_data: Array[ReactionData] = []

# CUSTOM ANIMATION SYSTEM (existing)
@export_group("Custom Animations")
@export var custom_animations: Array[CustomAnimation] = []

# BASE ANIMATIONS (existing - keeping all current functionality)
@export_group("Base Animations")
@export var entrance_animation: SpriteFrames
@export var idle_animation: SpriteFrames
@export var run_forward_animation: SpriteFrames
@export var run_backward_animation: SpriteFrames
@export var light_attack_animation: SpriteFrames
@export var heavy_attack_animation: SpriteFrames
@export var block_animation: SpriteFrames
@export var hit_animation: SpriteFrames
@export var special_attack_animation: SpriteFrames
@export var ultimate_attack_animation: SpriteFrames
@export var defeat_animation: SpriteFrames
@export var victory_animation: SpriteFrames

# Base animation scales and offsets (keeping for compatibility)
@export_group("Base Animation Settings")
@export var entrance_scale: Vector2 = Vector2(1.0, 1.0)
@export var idle_scale: Vector2 = Vector2(1.0, 1.0)
@export var run_forward_scale: Vector2 = Vector2(1.0, 1.0)
@export var run_backward_scale: Vector2 = Vector2(1.0, 1.0)
@export var light_attack_scale: Vector2 = Vector2(1.0, 1.0)
@export var heavy_attack_scale: Vector2 = Vector2(1.0, 1.0)
@export var block_scale: Vector2 = Vector2(1.0, 1.0)
@export var hit_scale: Vector2 = Vector2(1.0, 1.0)
@export var special_attack_scale: Vector2 = Vector2(1.5, 1.5)
@export var ultimate_attack_scale: Vector2 = Vector2(2.0, 2.0)
@export var defeat_scale: Vector2 = Vector2(1.0, 1.0)
@export var victory_scale: Vector2 = Vector2(1.2, 1.2)

# Sound effects
@export_group("Sound Effects")
@export var light_attack_sound: AudioStream
@export var heavy_attack_sound: AudioStream
@export var block_sound: AudioStream
@export var hit_sound: AudioStream
@export var special_attack_sound: AudioStream
@export var ultimate_attack_sound: AudioStream
@export var defeat_sound: AudioStream
@export var victory_sound: AudioStream

# Base animation offsets
@export_group("Base Animation Offsets")
@export var entrance_offset: Vector2 = Vector2(0.0, 0.0)
@export var idle_offset: Vector2 = Vector2(0.0, 0.0)
@export var run_forward_offset: Vector2 = Vector2(0.0, 0.0)
@export var run_backward_offset: Vector2 = Vector2(0.0, 0.0)
@export var light_attack_offset: Vector2 = Vector2(0.0, 0.0)
@export var heavy_attack_offset: Vector2 = Vector2(0.0, 0.0)
@export var block_offset: Vector2 = Vector2(0.0, 0.0)
@export var hit_offset: Vector2 = Vector2(0.0, 0.0)
@export var special_attack_offset: Vector2 = Vector2(0.0, 0.0)
@export var ultimate_attack_offset: Vector2 = Vector2(0.0, 0.0)
@export var defeat_offset: Vector2 = Vector2(0.0, 0.0)
@export var victory_offset: Vector2 = Vector2(0.0, 0.0)

# Character Select Portrait Animations
@export_group("Character Select Portraits")
@export var portrait_idle_frames: SpriteFrames
@export var portrait_hover_frames: SpriteFrames
@export var portrait_select_frames: SpriteFrames
@export var portrait_scale: Vector2 = Vector2(1.0, 1.0)

# NEW REACTION SYSTEM METHODS

# Find a specific reaction for an attacking character and attack type
func get_reaction_for_attack(attacking_character_id: String, attack_type: String) -> ReactionData:
	for reaction in reaction_data:
		if reaction.attacking_character_id == attacking_character_id and reaction.attack_type == attack_type:
			return reaction
	return null

# Check if this character has a specific reaction
func has_reaction_for_attack(attacking_character_id: String, attack_type: String) -> bool:
	return get_reaction_for_attack(attacking_character_id, attack_type) != null

# Get all reactions for a specific attacking character
func get_reactions_for_character(attacking_character_id: String) -> Array[ReactionData]:
	var character_reactions: Array[ReactionData] = []
	for reaction in reaction_data:
		if reaction.attacking_character_id == attacking_character_id:
			character_reactions.append(reaction)
	return character_reactions

# Add a new reaction
func add_reaction(new_reaction: ReactionData):
	# Check if reaction already exists and replace it
	for i in range(reaction_data.size()):
		var existing = reaction_data[i]
		if existing.attacking_character_id == new_reaction.attacking_character_id and existing.attack_type == new_reaction.attack_type:
			reaction_data[i] = new_reaction
			return
	
	# Add new reaction if it doesn't exist
	reaction_data.append(new_reaction)

# Remove a reaction
func remove_reaction(attacking_character_id: String, attack_type: String):
	for i in range(reaction_data.size() - 1, -1, -1):
		var reaction = reaction_data[i]
		if reaction.attacking_character_id == attacking_character_id and reaction.attack_type == attack_type:
			reaction_data.remove_at(i)
			break

# EXISTING METHODS (keeping all for compatibility)

func get_animation_offset(animation_name: String) -> Vector2:
	match animation_name:
		"entrance":
			return entrance_offset
		"idle":
			return idle_offset
		"run_forward":
			return run_forward_offset
		"run_backward":
			return run_backward_offset
		"light_attack":
			return light_attack_offset
		"heavy_attack":
			return heavy_attack_offset
		"block":
			return block_offset
		"hit":
			return hit_offset
		"special_attack":
			return special_attack_offset
		"ultimate_attack":
			return ultimate_attack_offset
		"defeat":
			return defeat_offset
		"victory":
			return victory_offset
		_:
			return Vector2(0.0, 0.0)

func get_animations_for_action(action_name: String) -> Array[CustomAnimation]:
	var bound_animations: Array[CustomAnimation] = []
	for custom_anim in custom_animations:
		if custom_anim.bound_to == action_name:
			bound_animations.append(custom_anim)
	return bound_animations

func get_animation_scale(animation_name: String) -> Vector2:
	var scale_multiplier: Vector2
	
	match animation_name:
		"entrance":
			scale_multiplier = entrance_scale
		"idle":
			scale_multiplier = idle_scale
		"run_forward":
			scale_multiplier = run_forward_scale
		"run_backward":
			scale_multiplier = run_backward_scale
		"light_attack":
			scale_multiplier = light_attack_scale
		"heavy_attack":
			scale_multiplier = heavy_attack_scale
		"block":
			scale_multiplier = block_scale
		"hit":
			scale_multiplier = hit_scale
		"special_attack":
			scale_multiplier = special_attack_scale
		"ultimate_attack":
			scale_multiplier = ultimate_attack_scale
		"defeat":
			scale_multiplier = defeat_scale
		"victory":
			scale_multiplier = victory_scale
		_:
			scale_multiplier = Vector2(1.0, 1.0)
	return base_scale * scale_multiplier

func has_base_animation(animation_name: String) -> bool:
	match animation_name:
		"entrance":
			return entrance_animation != null
		"idle":
			return idle_animation != null
		"run_forward":
			return run_forward_animation != null
		"run_backward":
			return run_backward_animation != null
		"light_attack":
			return light_attack_animation != null
		"heavy_attack":
			return heavy_attack_animation != null
		"block":
			return block_animation != null
		"hit":
			return hit_animation != null
		"special_attack":
			return special_attack_animation != null
		"ultimate_attack":
			return ultimate_attack_animation != null
		"defeat":
			return defeat_animation != null
		"victory":
			return victory_animation != null
		_:
			return false

func get_base_animation(animation_name: String) -> SpriteFrames:
	match animation_name:
		"entrance":
			return entrance_animation
		"idle":
			return idle_animation
		"run_forward":
			return run_forward_animation
		"run_backward":
			return run_backward_animation
		"light_attack":
			return light_attack_animation
		"heavy_attack":
			return heavy_attack_animation
		"block":
			return block_animation
		"hit":
			return hit_animation
		"special_attack":
			return special_attack_animation
		"ultimate_attack":
			return ultimate_attack_animation
		"defeat":
			return defeat_animation
		"victory":
			return victory_animation
		_:
			return null

func has_portrait_animation(animation_type: String) -> bool:
	match animation_type:
		"idle":
			return portrait_idle_frames != null
		"hover":
			return portrait_hover_frames != null
		"select":
			return portrait_select_frames != null
		_:
			return false

func get_portrait_animation(animation_type: String) -> SpriteFrames:
	match animation_type:
		"idle":
			return portrait_idle_frames
		"hover":
			return portrait_hover_frames
		"select":
			return portrait_select_frames
		_:
			return null

func get_victory_sound() -> AudioStream:
	return victory_sound
