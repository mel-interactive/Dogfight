extends Panel
class_name CharacterBox

var character_data: CharacterData
@onready var name_label = $InfoContainer/NameLabel
@onready var description_label = $InfoContainer/DescriptionLabel
@onready var background = $Background
@onready var animation_player = $AnimationPlayer

# NEW: Portrait sprite for character animations
@onready var portrait_sprite: AnimatedSprite2D

var is_hovered = false
var is_selected = false
var just_deselected = false  # Track if we just deselected to prevent hover override


func _ready():
	# Ensure we have a consistent size from the start
	custom_minimum_size = Vector2(140, 140)
	size_flags_horizontal = SIZE_FILL
	size_flags_vertical = SIZE_FILL
	
	# Create portrait sprite if it doesn't exist
	setup_portrait_sprite()
	
	# Initial state setup
	if description_label:
		description_label.visible = false
	
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")

func setup_portrait_sprite():
	# Check if we already have a portrait sprite
	if has_node("PortraitSprite"):
		portrait_sprite = $PortraitSprite
	else:
		# Create the portrait sprite
		portrait_sprite = AnimatedSprite2D.new()
		portrait_sprite.name = "PortraitSprite"
		add_child(portrait_sprite)
	
	# Connect to animation finished signal
	if not portrait_sprite.is_connected("animation_finished", _on_portrait_animation_finished):
		portrait_sprite.connect("animation_finished", _on_portrait_animation_finished)
	
	# Position the sprite at the top-center of the box
	update_portrait_position()
	portrait_sprite.z_index = 1  # Above background but below text
	
	# Connect to the resized signal to update scaling when box size changes
	if not is_connected("resized", _on_box_resized):
		connect("resized", _on_box_resized)

func _on_box_resized():
	# Update portrait position and scale when the box is resized
	if portrait_sprite:
		update_portrait_position()
		update_portrait_scale()

func update_portrait_position():
	if not portrait_sprite:
		return
	
	# Position at top-center of the box
	portrait_sprite.position.x = size.x / 2.0  # Center horizontally
	portrait_sprite.position.y = 0  # Top of the box
	
	# Offset by half the sprite height so the top of the sprite aligns with top of box
	# This will be updated after we calculate the scale in update_portrait_scale()

func update_portrait_scale():
	if not portrait_sprite or not portrait_sprite.sprite_frames or not character_data:
		return
	
	# Get the current frame to calculate its size
	var current_animation = portrait_sprite.animation
	if current_animation == "" or not portrait_sprite.sprite_frames.has_animation(current_animation):
		return
	
	var current_frame_index = portrait_sprite.frame
	var frame_texture = portrait_sprite.sprite_frames.get_frame_texture(current_animation, current_frame_index)
	
	if not frame_texture:
		return
	
	# Get frame dimensions
	var frame_size = Vector2(frame_texture.get_width(), frame_texture.get_height())
	
	# Use full available space (no padding)
	var available_space = size
	
	# Calculate scale to fit while maintaining aspect ratio
	var scale_x = available_space.x / frame_size.x
	var scale_y = available_space.y / frame_size.y
	
	# Use the smaller scale to ensure it fits completely (letterbox/pillarbox approach)
	var uniform_scale = min(scale_x, scale_y)
	
	# Apply the base character scale multiplied by the fit scale
	portrait_sprite.scale = character_data.portrait_scale * uniform_scale
	
	# Update position to keep it anchored to the top after scaling (no padding)
	portrait_sprite.position.x = size.x / 2.0  # Keep centered horizontally
	
	# Calculate the scaled height and position to anchor to top with no padding
	var scaled_height = frame_size.y * portrait_sprite.scale.y
	portrait_sprite.position.y = scaled_height / 2.0  # No padding, just half sprite height from top

func set_character(data: CharacterData):
	character_data = data
	
	# Null checks to avoid errors
	if not is_instance_valid(data):
		push_error("Invalid character data passed to CharacterBox")
		return
	
	if name_label:
		name_label.text = data.character_name
	else:
		push_error("Name label not found in CharacterBox")
	
	if description_label:
		description_label.text = data.description
	
	#if background:
		#background.self_modulate = data.color
	
	# Setup portrait animations
	setup_portrait_animations()
	
	print("CharacterBox set up for: " + data.character_name)

func setup_portrait_animations():
	if not portrait_sprite or not character_data:
		return
	
	# Create a new SpriteFrames resource for this portrait
	portrait_sprite.sprite_frames = SpriteFrames.new()
	
	# Add portrait animations to the sprite
	if character_data.has_portrait_animation("idle"):
		add_portrait_animation("idle", character_data.get_portrait_animation("idle"))
	
	if character_data.has_portrait_animation("hover"):
		add_portrait_animation("hover", character_data.get_portrait_animation("hover"))
	
	if character_data.has_portrait_animation("select"):
		add_portrait_animation("select", character_data.get_portrait_animation("select"))
	
	# Apply scale
	portrait_sprite.scale = character_data.portrait_scale
	
	# Start with idle (still frame)
	play_portrait_animation("idle")
	
	# Update scale to fit the current box size
	call_deferred("update_portrait_scale")

func _on_portrait_animation_finished():
	# When select animation finishes in reverse and we're hovered, show hover state
	if just_deselected and is_hovered:
		print("Select reverse finished - showing hover state for: ", character_data.character_name if character_data else "unknown")
		# Show the last frame of hover animation (pause on it)
		if portrait_sprite.sprite_frames.has_animation("hover"):
			var frame_count = portrait_sprite.sprite_frames.get_frame_count("hover")
			portrait_sprite.play("hover")
			portrait_sprite.pause()
			portrait_sprite.frame = frame_count - 1  # Last frame of hover
		just_deselected = false

func add_portrait_animation(anim_name: String, frames: SpriteFrames):
	if not frames or not portrait_sprite.sprite_frames:
		return
	
	var source_animations = frames.get_animation_names()
	if source_animations.size() == 0:
		return
	
	var source_anim_name = source_animations[0]
	if frames.get_frame_count(source_anim_name) == 0:
		return
	
	# Create the animation
	if not portrait_sprite.sprite_frames.has_animation(anim_name):
		portrait_sprite.sprite_frames.add_animation(anim_name)
	
	# Copy frames
	for i in range(frames.get_frame_count(source_anim_name)):
		var frame_texture = frames.get_frame_texture(source_anim_name, i)
		if frame_texture:
			portrait_sprite.sprite_frames.add_frame(anim_name, frame_texture)
	
	# Set animation properties
	if portrait_sprite.sprite_frames.get_frame_count(anim_name) > 0:
		portrait_sprite.sprite_frames.set_animation_speed(anim_name, frames.get_animation_speed(source_anim_name))
		
		# Set looping behavior
		if anim_name == "idle":
			# Idle should not loop - it's just a still frame
			portrait_sprite.sprite_frames.set_animation_loop(anim_name, false)
		elif anim_name == "hover":
			# Hover should not loop - play once and hold on last frame
			portrait_sprite.sprite_frames.set_animation_loop(anim_name, false)
		elif anim_name == "select":
			# Select should not loop - play once and hold
			portrait_sprite.sprite_frames.set_animation_loop(anim_name, false)

func play_portrait_animation(anim_name: String, reverse: bool = false):
	if not portrait_sprite or not portrait_sprite.sprite_frames:
		return
	
	if not portrait_sprite.sprite_frames.has_animation(anim_name):
		# Fallback: if animation doesn't exist, try to show first frame of hover
		if anim_name == "idle" and portrait_sprite.sprite_frames.has_animation("hover"):
			portrait_sprite.play("hover")
			portrait_sprite.pause()  # Pause on first frame
			portrait_sprite.frame = 0
		return
	
	if anim_name == "idle":
		# For idle, show first frame of hover animation and pause
		if portrait_sprite.sprite_frames.has_animation("hover"):
			portrait_sprite.play("hover")
			portrait_sprite.pause()
			portrait_sprite.frame = 0
		else:
			portrait_sprite.play(anim_name)
			portrait_sprite.pause()
			portrait_sprite.frame = 0
	else:
		# Try using play_backwards for reverse
		if reverse:
			print("Attempting to play ", anim_name, " backwards using play_backwards()")
			if portrait_sprite.has_method("play_backwards"):
				portrait_sprite.play_backwards(anim_name)
				# Make reverse animations faster (2x speed)
				portrait_sprite.speed_scale = 2.0
			else:
				print("play_backwards() method not available, trying manual reverse")
				# Manual approach: start from last frame and use negative speed
				portrait_sprite.play(anim_name)
				var frame_count = portrait_sprite.sprite_frames.get_frame_count(anim_name)
				portrait_sprite.frame = frame_count - 1
				portrait_sprite.speed_scale = -2.0  # Negative speed for reverse, 2x faster
		else:
			print("Playing ", anim_name, " forward normally")
			portrait_sprite.speed_scale = 1.0  # Normal speed for forward
			portrait_sprite.play(anim_name)
		
		# Update scale after animation starts to ensure proper sizing
		call_deferred("update_portrait_scale")

func set_hovered(hovered: bool):
	# Check just_deselected BEFORE clearing it
	var should_skip_ui_hover = just_deselected
	
	is_hovered = hovered
	
	if hovered:
		z_index = 1  # Bring to front
		if description_label:
			description_label.visible = true  # Show description when hovered
		
		# Only play hover if we didn't just deselect (let select reverse finish)
		if not is_selected and not just_deselected:
			print("Playing hover animation forward for: ", character_data.character_name if character_data else "unknown")
			play_portrait_animation("hover", false)
		elif just_deselected:
			print("Skipping hover animation - just deselected, letting select reverse play for: ", character_data.character_name if character_data else "unknown")
			just_deselected = false  # Clear the flag
	else:
		z_index = 0  # Normal depth
		if description_label and not is_selected:
			description_label.visible = false  # Hide description when not hovered
		
		# Play hover backward if not selected
		if not is_selected:
			print("Playing hover animation backward for: ", character_data.character_name if character_data else "unknown")
			play_portrait_animation("hover", true)
		
		just_deselected = false  # Clear flag when unhovered
	
	# Handle UI AnimationPlayer for box animations - use the saved flag value
	if animation_player:
		if hovered and animation_player.has_animation("hover") and not should_skip_ui_hover:
			print("Playing UI hover animation for: ", character_data.character_name if character_data else "unknown")
			animation_player.play("hover")
		elif hovered and should_skip_ui_hover:
			print("Skipping UI hover animation - just deselected for: ", character_data.character_name if character_data else "unknown")
		elif not hovered and not is_selected and animation_player.has_animation("hover"):
			print("Playing UI hover animation backwards for: ", character_data.character_name if character_data else "unknown")
			animation_player.play_backwards("hover")

func set_selected(selected: bool):
	is_selected = selected
	
	if selected:
		# Play select animation forward
		print("Playing select animation forward for: ", character_data.character_name if character_data else "unknown")
		play_portrait_animation("select", false)
		$CPUParticles2D.emitting = true
		just_deselected = false  # Clear flag when selecting
	else:
		# Play select animation in reverse when deselecting
		print("Playing select animation backward for: ", character_data.character_name if character_data else "unknown")
		play_portrait_animation("select", true)
		just_deselected = true  # Set flag to prevent hover from overriding
	
	# Handle UI AnimationPlayer for selection
	if animation_player:
		if selected and animation_player.has_animation("select"):
			print("Playing UI select animation for: ", character_data.character_name if character_data else "unknown")
			animation_player.play("select")
		elif not selected and animation_player.has_animation("select"):
			# Just reverse the UI select animation too
			print("Playing UI select animation backwards for: ", character_data.character_name if character_data else "unknown")
			animation_player.play_backwards("select")
