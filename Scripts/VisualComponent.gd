# VisualComponent.gd - Complete version with animation offsets
extends Node
class_name VisualComponent

var character: BaseCharacter
var sprite: AnimatedSprite2D
var custom_animation_sprites: Array[AnimatedSprite2D] = []
var original_sprite_position: Vector2
var shake_offset: Vector2 = Vector2.ZERO

# Speed lines
var speed_lines_sprite: AnimatedSprite2D
var speed_lines_active: bool = false

func _ready():
	character = get_parent()
	setup_speed_lines()

func setup_speed_lines():
	# Create speed lines sprite
	speed_lines_sprite = AnimatedSprite2D.new()
	speed_lines_sprite.name = "SpeedLines"
	speed_lines_sprite.visible = false
	speed_lines_sprite.z_index = 15
	character.add_child(speed_lines_sprite)
	
	# Load the speed lines animation
	var speed_lines_path = "res://Assets/Effects/Animations/speedlines.tres"
	
	if ResourceLoader.exists(speed_lines_path):
		var speed_lines_frames = ResourceLoader.load(speed_lines_path) as SpriteFrames
		if speed_lines_frames:
			speed_lines_sprite.sprite_frames = speed_lines_frames

func start_speed_lines():
	speed_lines_active = true
	speed_lines_sprite.visible = true
	speed_lines_sprite.scale = Vector2(1.5, 1.5)

	# Get available animations from the speed lines
	var available_animations = speed_lines_sprite.sprite_frames.get_animation_names()
	
	if available_animations.size() > 0:
		var anim_name = available_animations[0]
		speed_lines_sprite.play(anim_name)
		
		# Force initial positioning - move UP from character position
		speed_lines_sprite.global_position = character.global_position

func stop_speed_lines():
	if speed_lines_sprite:
		speed_lines_active = false
		speed_lines_sprite.visible = false
		speed_lines_sprite.stop()

func update_speed_lines_direction(movement_direction: Vector2):
	if not speed_lines_active or not speed_lines_sprite:
		return
	
	# Position speed lines ABOVE the character, not at their feet
	speed_lines_sprite.global_position = character.global_position
	speed_lines_sprite.global_position.y -= 200
	
	if character.player_number == 1:
		if movement_direction.x < 0:
			speed_lines_sprite.flip_h = true  # Moving left, lines go right
			speed_lines_sprite.global_position.x += 250 
		elif movement_direction.x > 0:
			speed_lines_sprite.flip_h = false  # Moving right, lines go left
			speed_lines_sprite.global_position.x -= 100 
	elif character.player_number == 2:
		if movement_direction.x < 0:
			speed_lines_sprite.flip_h = true  # Moving left, lines go right
			speed_lines_sprite.global_position.x += 100 
		elif movement_direction.x > 0:
			speed_lines_sprite.flip_h = false  # Moving right, lines go left
			speed_lines_sprite.global_position.x -= 250 

func setup_visuals():
	# Clean up existing sprites
	if character.has_node("DebugSprite"):
		character.get_node("DebugSprite").queue_free()
	if character.has_node("Sprite"):
		character.get_node("Sprite").queue_free()
	
	# Clear custom animation sprites
	for custom_sprite in custom_animation_sprites:
		if is_instance_valid(custom_sprite):
			custom_sprite.queue_free()
	custom_animation_sprites.clear()
	
	# Create main animated sprite
	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.z_index = 0
	character.add_child(sprite)
	sprite.connect("animation_finished", _on_animation_finished)
	
	# Store reference in character
	character.sprite = sprite
	
	# Setup base animations
	setup_base_animations()
	
	# Setup custom animations
	setup_custom_animations()
	
	# Setup speed lines
	setup_speed_lines()
	
	# Store original sprite position for shake effect
	if sprite:
		original_sprite_position = sprite.position

func setup_base_animations():
	sprite.sprite_frames = SpriteFrames.new()
	var has_animations = false
	
	# Add base animations - including "entrance"
	var base_animations = [
		"idle", "run_forward", "run_backward", "light_attack",
		"heavy_attack", "block", "hit", "special_attack",
		"ultimate_attack", "defeat", "entrance", "victory"
	]
	
	for anim_name in base_animations:
		if character.character_data.has_base_animation(anim_name):
			var base_anim = character.character_data.get_base_animation(anim_name)
			add_animation(anim_name, base_anim)
			has_animations = true
	
	# Start with idle or first available animation
	if has_animations:
		if sprite.sprite_frames.has_animation("idle"):
			play_animation("idle")
		else:
			var available_animations = sprite.sprite_frames.get_animation_names()
			if available_animations.size() > 0:
				play_animation(available_animations[0])
		set_sprite_anchor_bottom()
	else:
		# Create debug sprite if no animations
		create_debug_sprite()

func setup_custom_animations():
	# Create sprite nodes for each custom animation
	for i in range(character.character_data.custom_animations.size()):
		var custom_anim = character.character_data.custom_animations[i]
		if not custom_anim.animation_frames:
			continue
			
		var custom_sprite = AnimatedSprite2D.new()
		custom_sprite.name = "CustomSprite" + str(i)
		custom_sprite.visible = false
		custom_sprite.z_index = 10
		character.add_child(custom_sprite)
		
		# Setup the animation
		custom_sprite.sprite_frames = custom_anim.animation_frames
		custom_sprite.connect("animation_finished", _on_custom_animation_finished.bind(i))
		
		custom_animation_sprites.append(custom_sprite)

func create_debug_sprite():
	var img = Image.create(50, 100, false, Image.FORMAT_RGBA8)
	img.fill(character.character_data.color)
	var tex = ImageTexture.create_from_image(img)
	
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.add_animation("debug")
	sprite.sprite_frames.add_frame("debug", tex)
	sprite.play("debug")
	sprite.flip_h = (character.player_number == 1)
	set_sprite_anchor_bottom()

func set_sprite_anchor_bottom():
	if not sprite:
		return
	
	# Get current animation offset
	var current_anim_offset = Vector2.ZERO
	if sprite.animation != "":
		var base_offset = character.character_data.get_animation_offset(sprite.animation)
		current_anim_offset = base_offset
		
		# Flip X offset for player 1
		if character.player_number == 1:
			current_anim_offset.x = -current_anim_offset.x
	
	# Apply the base position + animation offset
	sprite.position.y = original_sprite_position.y + current_anim_offset.y
	sprite.position.x = original_sprite_position.x + current_anim_offset.x
	
	if sprite.sprite_frames and sprite.animation != "":
		var current_frame = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if current_frame:
			var frame_width = current_frame.get_width()
			var frame_height = current_frame.get_height()
			
			# Use float division to avoid integer division warnings
			sprite.offset.y = -frame_height / 2.0
			
			if character.player_number == 1:
				sprite.offset.x = frame_width / 2.0
			else:
				sprite.offset.x = -frame_width / 2.0
		else:
			sprite.offset.y = -50
			sprite.offset.x = 25 if character.player_number == 1 else -25
	else:
		sprite.offset.y = -50
		sprite.offset.x = 25 if character.player_number == 1 else -25

func do_simple_shake():
	if not sprite:
		return
	
	# Move sprite backwards based on player number (taking a hit)
	var backward_x = -10 if character.player_number == 1 else 10
	shake_offset = Vector2(backward_x, 0)
	sprite.position = original_sprite_position + shake_offset
	
	# Flash sprite closer to white
	sprite.modulate = Color(1.5, 1.5, 1.5, 1.0)
	
	# Return to normal position and color after a brief moment
	var timer = Timer.new()
	character.add_child(timer)
	timer.wait_time = 0.1
	timer.one_shot = true
	timer.timeout.connect(_reset_sprite_position)
	timer.timeout.connect(timer.queue_free)
	timer.start()

func _reset_sprite_position():
	if sprite:
		sprite.position = original_sprite_position
		sprite.modulate = Color.WHITE
		shake_offset = Vector2.ZERO

func play_animation(animation_name: String):
	if not sprite or not sprite.sprite_frames:
		return
		
	if not sprite.sprite_frames.has_animation(animation_name):
		return
	
	sprite.play(animation_name)
	
	var target_scale = character.character_data.get_animation_scale(animation_name)
	sprite.scale = target_scale
	sprite.flip_h = (character.player_number == 1)
	
	# Apply animation offset (flipped for player 1)
	var base_offset = character.character_data.get_animation_offset(animation_name)
	var final_offset = base_offset
	
	# Flip X offset for player 1 (same logic as sprite flipping)
	if character.player_number == 1:
		final_offset.x = -final_offset.x
	
	# Apply the offset to sprite position
	sprite.position = original_sprite_position + final_offset
	
	call_deferred("set_sprite_anchor_bottom")
	
	# Play all custom animations bound to this base animation
	play_custom_animations_for_action(animation_name)
	
	EventBus.emit_signal("animation_started", character, animation_name)

func play_custom_animations_for_action(action_name: String):
	var bound_animations = character.character_data.get_animations_for_action(action_name)
	
	for i in range(bound_animations.size()):
		var custom_anim = bound_animations[i]
		
		# Find the sprite index in our custom_animation_sprites array
		var sprite_index = character.character_data.custom_animations.find(custom_anim)
		if sprite_index == -1 or sprite_index >= custom_animation_sprites.size():
			continue
			
		var custom_sprite = custom_animation_sprites[sprite_index]
		if not custom_sprite or not custom_sprite.sprite_frames:
			continue
			
		# Get first available animation from the custom sprite frames
		var available_animations = custom_sprite.sprite_frames.get_animation_names()
		if available_animations.size() == 0:
			continue
			
		var anim_name = available_animations[0]
		
		# Apply settings
		custom_sprite.scale = character.character_data.base_scale * custom_anim.scale
		
		# Handle flipping
		if custom_anim.flip_with_player:
			custom_sprite.flip_h = (character.player_number == 1)
		else:
			custom_sprite.flip_h = false
		
		# Position the custom animation
		position_custom_animation(custom_sprite, custom_anim)
		
		# Play the animation
		custom_sprite.play(anim_name)
		custom_sprite.visible = true

func position_custom_animation(custom_sprite: AnimatedSprite2D, custom_anim: CustomAnimation):
	if custom_anim.anchored_to_player:
		# Position relative to the main sprite
		custom_sprite.global_position = sprite.global_position
		
		# Reset offset to center the sprite first
		custom_sprite.offset = Vector2.ZERO
		
		# Add offset - flip X for player 1 (same as sprite flipping logic)
		var offset_to_use = custom_anim.position_offset
		if character.player_number == 1:
			offset_to_use.x = -offset_to_use.x
		
		custom_sprite.global_position += offset_to_use
	else:
		# Position at screen center
		var viewport_size = character.get_viewport().get_visible_rect().size
		custom_sprite.global_position = Vector2(viewport_size.x / 2.0, viewport_size.y / 2.0)
		
		# Reset offset to center the sprite first
		custom_sprite.offset = Vector2.ZERO
		
		custom_sprite.global_position += custom_anim.position_offset

func _on_custom_animation_finished(sprite_index: int):
	if sprite_index < custom_animation_sprites.size():
		var custom_sprite = custom_animation_sprites[sprite_index]
		custom_sprite.visible = false

func _on_animation_finished():
	var anim_name = sprite.animation
	
	# Emit to EventBus
	EventBus.emit_signal("animation_finished", character, anim_name)
	
	# Also emit the character's legacy signal for compatibility
	character.emit_signal("animation_finished", anim_name)
	
	# Forward to character's _on_animation_finished method
	character._on_animation_finished()

func add_animation(anim_name: String, frames: SpriteFrames):
	if not frames or not sprite.sprite_frames:
		return
		
	var source_animations = frames.get_animation_names()
	if source_animations.size() == 0:
		return
		
	var source_anim_name = source_animations[0]
	if frames.get_frame_count(source_anim_name) == 0:
		return
		
	if not sprite.sprite_frames.has_animation(anim_name):
		sprite.sprite_frames.add_animation(anim_name)
		
	for i in range(frames.get_frame_count(source_anim_name)):
		var frame_texture = frames.get_frame_texture(source_anim_name, i)
		if frame_texture:
			sprite.sprite_frames.add_frame(anim_name, frame_texture)
	
	if sprite.sprite_frames.get_frame_count(anim_name) > 0:
		sprite.sprite_frames.set_animation_speed(anim_name, frames.get_animation_speed(source_anim_name))
		
		if "attack" in anim_name or anim_name == "hit" or anim_name == "defeat" or anim_name == "entrance":
			sprite.sprite_frames.set_animation_loop(anim_name, false)
		else:
			sprite.sprite_frames.set_animation_loop(anim_name, frames.get_animation_loop(source_anim_name))
