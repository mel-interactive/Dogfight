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

# NEW CUSTOM ANIMATION SYSTEM
@export_group("Custom Animations")
@export var custom_animations: Array[CustomAnimation] = []

# BASE ANIMATIONS (Keep the original system for base animations)
@export_group("Base Animations")
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

# Base animation scales and offsets (keeping for compatibility)
@export_group("Base Animation Settings")
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

# Sound effects
@export_group("Sound Effects")
@export var light_attack_sound: AudioStream
@export var heavy_attack_sound: AudioStream
@export var block_sound: AudioStream
@export var hit_sound: AudioStream
@export var special_attack_sound: AudioStream
@export var ultimate_attack_sound: AudioStream
@export var defeat_sound: AudioStream

# Get all animations bound to a specific base animation
func get_animations_for_action(action_name: String) -> Array[CustomAnimation]:
	var bound_animations: Array[CustomAnimation] = []
	for custom_anim in custom_animations:
		if custom_anim.bound_to == action_name:
			bound_animations.append(custom_anim)
	return bound_animations

# Helper function to get scale for a specific base animation
func get_animation_scale(animation_name: String) -> Vector2:
	var scale_multiplier: Vector2
	
	match animation_name:
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
		_:
			scale_multiplier = Vector2(1.0, 1.0)
	return base_scale * scale_multiplier

# Check if base animation exists
func has_base_animation(animation_name: String) -> bool:
	match animation_name:
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
		_:
			return false

# Get base animation
func get_base_animation(animation_name: String) -> SpriteFrames:
	match animation_name:
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
		_:
			return null
