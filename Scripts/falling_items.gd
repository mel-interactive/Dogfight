extends Node2D
class_name FallingItem

# Node references
@onready var warning: TextureRect = $Warning
@onready var falling_item: TextureRect = $"falling item"
@onready var area_2d: Area2D = $"falling item/Area2D"
@onready var collision_shape: CollisionShape2D = $"falling item/Area2D/CollisionShape2D"

# Configuration
@export var warning_flash_count: int = 3
@export var warning_flash_duration: float = 0.2
@export var fall_delay: float = 1.0
@export var gravity: float = 980.0
@export var damage: int = 75
@export var starting_y_offset: float = -200.0

# Pitch variation range (e.g., 0.9 to 1.1 gives ±10% variation)
@export var min_pitch: float = 0.85
@export var max_pitch: float = 1.15

# Item textures
@export var item_textures: Array[String] = [
	"res://Assets/Falling items/mick.png",
	"res://Assets/Falling items/backpack.png",
	"res://Assets/Falling items/coffee.png",
	"res://Assets/Falling items/computer.png",
	"res://Assets/Falling items/connectfour.png",
	"res://Assets/Falling items/desk.png",
	"res://Assets/Falling items/whiteboard.png",
]

# Sound effects
@export var warning_sound: AudioStream
@export var impact_sound: AudioStream

# Audio players
var warning_audio: AudioStreamPlayer2D
var impact_audio: AudioStreamPlayer2D

# State tracking
var velocity: float = 0.0
var is_falling: bool = false
var has_hit_player: bool = false
var screen_bottom: float = 720.0

func _ready():
	print("FallingItem: _ready() called")
	print("FallingItem position: ", position)
	
	# Create audio players
	warning_audio = AudioStreamPlayer2D.new()
	impact_audio = AudioStreamPlayer2D.new()
	add_child(warning_audio)
	add_child(impact_audio)
	
	# Set up audio
	if warning_sound:
		warning_audio.stream = warning_sound
	if impact_sound:
		impact_audio.stream = impact_sound
	
	# Connect area signal for detecting player hits
	if area_2d:
		print("Connecting area2d signal")
		area_2d.body_entered.connect(_on_body_entered)
		# Set up collision detection
		area_2d.monitoring = true
		area_2d.monitorable = true
	else:
		print("WARNING: area_2d is null!")
	
	# Check if nodes exist
	if not warning:
		print("WARNING: warning node not found!")
	if not falling_item:
		print("WARNING: falling_item node not found!")
	
	# Start invisible
	if warning:
		warning.visible = false
	if falling_item:
		falling_item.visible = false
	
	# Get screen height from viewport
	screen_bottom = get_viewport_rect().size.y
	print("Screen bottom: ", screen_bottom)

func _physics_process(delta):
	if is_falling:
		# Apply gravity
		velocity += gravity * delta
		
		# Move downward
		position.y += velocity * delta
		
		# Debug: print position occasionally
		if int(position.y) % 100 == 0:
			print("FallingItem falling at y: ", position.y, " velocity: ", velocity)
		
		# Check if reached bottom of screen
		if position.y >= screen_bottom:
			print("FallingItem reached bottom at: ", position.y)
			_on_reached_bottom()

# Initialize the falling item at a specific position
func initialize(spawn_position: Vector2):
	print("FallingItem: initialize() called at position: ", spawn_position)
	position = spawn_position
	position.y += starting_y_offset
	print("FallingItem: Starting position (with offset): ", position)
	
	# Choose random item texture
	if item_textures.size() > 0:
		var random_texture_path = item_textures[randi() % item_textures.size()]
		print("Loading texture: ", random_texture_path)
		var texture = load(random_texture_path)
		if texture:
			falling_item.texture = texture
			print("Texture loaded successfully")
		else:
			print("WARNING: Failed to load texture!")
	else:
		print("WARNING: No item textures defined!")
	
	# Start the warning sequence
	start_warning()

# Helper function to randomize pitch
func randomize_pitch(audio_player: AudioStreamPlayer2D):
	audio_player.pitch_scale = randf_range(min_pitch, max_pitch)

# Start the warning flash sequence
func start_warning():
	print("FallingItem: start_warning() called")
	
	if not warning:
		print("WARNING: warning node is null in start_warning!")
		start_falling()
		return
	
	warning.visible = true
	print("Warning visible set to true")
	
	# Play warning sound with randomized pitch
	if warning_audio and warning_audio.stream:
		randomize_pitch(warning_audio)
		warning_audio.play()
		print("Warning sound playing at pitch: ", warning_audio.pitch_scale)
	
	# Flash the warning
	for i in range(warning_flash_count):
		warning.visible = true
		await get_tree().create_timer(warning_flash_duration).timeout
		warning.visible = false
		await get_tree().create_timer(warning_flash_duration).timeout
		print("Warning flash ", i + 1, " completed")
	
	# Hide warning and start falling
	warning.visible = false
	start_falling()

# Begin falling
func start_falling():
	print("FallingItem: start_falling() called")
	
	if not falling_item:
		print("WARNING: falling_item node is null!")
		return
	
	falling_item.visible = true
	is_falling = true
	velocity = 0.0
	print("Item now falling, visible: ", falling_item.visible)

# Handle collision with player
func _on_body_entered(body):
	print("FallingItem: _on_body_entered called with body: ", body.name)
	
	if has_hit_player or not is_falling:
		print("Already hit player or not falling, ignoring")
		return
	
	# Check if the body is a player character
	if body is BaseCharacter:
		has_hit_player = true
		print("HIT PLAYER! Dealing ", damage, " damage to player ", body.player_number)
		
		# Deal damage to the player
		body.take_damage(damage, true)
		
		# Disappear after hitting
		_cleanup()
	else:
		print("Body is not a BaseCharacter, it's: ", body.get_class())

# Handle reaching the bottom of the screen
func _on_reached_bottom():
	print("FallingItem: _on_reached_bottom() called")
	_cleanup()

# Clean up and remove the item
func _cleanup():
	print("FallingItem: _cleanup() called")
	is_falling = false
	
	# Play impact sound with randomized pitch
	if impact_audio and impact_audio.stream:
		randomize_pitch(impact_audio)
		impact_audio.play()
		print("Playing impact sound at pitch: ", impact_audio.pitch_scale)
		# Wait for sound to finish before removing
	
	# Remove from scene
	print("FallingItem: Removing from scene")
	queue_free()
