extends Resource
class_name CustomAnimation

# The animation frames
@export var animation_frames: SpriteFrames

# Which base animation this is bound to
@export_enum("idle", "run_forward", "run_backward", "light_attack", "heavy_attack", "block", "hit", "special_attack", "ultimate_attack", "defeat") var bound_to: String = "idle"

# Visual settings
@export var flip_with_player: bool = true
@export var anchored_to_player: bool = true  # false means centered on screen
@export var scale: Vector2 = Vector2(1.0, 1.0)
@export var position_offset: Vector2 = Vector2.ZERO
