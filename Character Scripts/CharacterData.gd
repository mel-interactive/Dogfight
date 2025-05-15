extends Resource
class_name CharacterData

# Basic info
@export var character_id: String = "default"
@export var character_name: String = "Default Fighter"
@export var description: String = "A basic fighter"

# Visual properties
@export var sprite_texture: Texture2D
@export var color: Color = Color.WHITE

# Stats
@export var max_health: int = 100
@export var move_speed: float = 300.0

# Attack properties
@export var light_attack_damage: int = 5
@export var heavy_attack_damage: int = 15
@export var special_attack_damage: int = 25
@export var ultimate_attack_damage: int = 40

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

# Animation resources
@export_group("Animations")
@export var idle_animation: SpriteFrames
@export var run_animation: SpriteFrames 
@export var light_attack_animation: SpriteFrames
@export var heavy_attack_animation: SpriteFrames
@export var block_animation: SpriteFrames
@export var hit_animation: SpriteFrames
@export var special_attack_animation: SpriteFrames
@export var ultimate_attack_animation: SpriteFrames
@export var defeat_animation: SpriteFrames

# Sound effects
@export_group("Sound Effects")
@export var light_attack_sound: AudioStream
@export var heavy_attack_sound: AudioStream
@export var block_sound: AudioStream
@export var hit_sound: AudioStream
@export var special_attack_sound: AudioStream
@export var ultimate_attack_sound: AudioStream
@export var defeat_sound: AudioStream
