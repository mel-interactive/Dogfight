# ReactionData.gd - Defines a specific reaction animation for character interactions
extends Resource
class_name ReactionData

# Which character this reaction is FOR (the one being attacked)
@export var target_character_id: String = ""

# Which character this reaction is AGAINST (the one attacking)
@export var attacking_character_id: String = ""

# What type of attack this reacts to
@export_enum("special_attack", "ultimate_attack") var attack_type: String = "special_attack"

# The reaction animation
@export var reaction_animation: SpriteFrames

# Visual settings for the reaction
@export var reaction_scale: Vector2 = Vector2(1.0, 1.0)
@export var reaction_offset: Vector2 = Vector2(0.0, 0.0)
@export var flip_with_player: bool = true

# Additional animations that play alongside this reaction (self-contained)
@export var additional_animations: Array[SpriteFrames] = []
@export var additional_animation_scales: Array[Vector2] = []
@export var additional_animation_offsets: Array[Vector2] = []
@export var additional_animation_flips: Array[bool] = []  # Whether each additional animation flips with player

# Optional sound effect for this specific reaction
@export var reaction_sound: AudioStream

# Duration override (if 0, uses default hit duration)
@export var duration_override: float = 0.0
