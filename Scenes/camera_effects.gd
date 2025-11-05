# CameraEffect.gd - Gradual camera shake that increases over fight duration
extends Node2D

# Shake parameters
@export var shake_enabled: bool = true
@export var shake_increase_rate: float = 0.5  # How fast shake intensity increases per second
@export var max_shake_intensity: float = 3.0  # Maximum shake strength (in pixels)
@export var shake_frequency: float = 30.0  # How fast the shake oscillates (higher = faster)

# Internal state
var current_shake_intensity: float = 0.0
var fight_duration: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO
var noise: FastNoiseLite

# Reference to fight scene
var fight_scene: FightScene

func _ready():
	# Store original position
	original_position = position
	
	# Setup noise for smooth random shake
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.1
	
	# Get reference to parent FightScene
	fight_scene = get_parent()
	if not fight_scene or not fight_scene is FightScene:
		push_error("CameraEffect must be a child of FightScene!")
		return
	
	print("CameraEffect initialized")

func _process(delta: float):
	if not shake_enabled or not fight_scene:
		return
	
	# Only shake when fight is active (not during intro or after KO)
	if not fight_scene.fight_active or fight_scene.fight_over:
		# Reset shake when fight isn't active
		if current_shake_intensity > 0:
			smoothly_reset_shake(delta)
		return
	
	# Increase fight duration and shake intensity
	fight_duration += delta
	
	# Gradually increase shake intensity (capped at max)
	current_shake_intensity = min(
		current_shake_intensity + (shake_increase_rate * delta),
		max_shake_intensity
	)
	
	# Calculate shake offset using noise for smooth random motion
	var noise_x = noise.get_noise_2d(fight_duration * shake_frequency, 0.0)
	var noise_y = noise.get_noise_2d(0.0, fight_duration * shake_frequency)
	
	shake_offset = Vector2(
		noise_x * current_shake_intensity,
		noise_y * current_shake_intensity
	)
	
	# Apply shake to position
	position = original_position + shake_offset

func smoothly_reset_shake(delta: float):
	"""Smoothly return to original position when fight ends"""
	# Gradually reduce shake intensity
	current_shake_intensity = max(0.0, current_shake_intensity - (shake_increase_rate * 2.0 * delta))
	
	# Lerp back to original position
	position = position.lerp(original_position, 5.0 * delta)
	
	# Reset fight duration when shake is fully gone
	if current_shake_intensity <= 0.01:
		current_shake_intensity = 0.0
		fight_duration = 0.0
		position = original_position

func reset_shake():
	"""Immediately reset shake effect (useful for new rounds)"""
	current_shake_intensity = 0.0
	fight_duration = 0.0
	shake_offset = Vector2.ZERO
	position = original_position

# Optional: Add method to manually trigger intense shake (for special moments)
func add_shake_burst(intensity: float, duration: float = 0.2):
	"""Add a temporary shake burst (e.g., for ultimate attacks)"""
	var original_intensity = current_shake_intensity
	current_shake_intensity = min(current_shake_intensity + intensity, max_shake_intensity * 2.0)
	
	# Return to normal after duration
	await get_tree().create_timer(duration).timeout
	current_shake_intensity = original_intensity


# NEW: Trigger a small shake when damage is taken
func add_damage_shake(damage_amount: float = 10.0):
	"""Add a small shake burst based on damage taken"""
	# Scale shake intensity based on damage (more damage = more shake)
	# Typical damage range might be 5-50, so we scale it down
	var shake_intensity = clamp(damage_amount * 0.1, 0.5, 5.0)
	add_shake_burst(shake_intensity, 0.15)
