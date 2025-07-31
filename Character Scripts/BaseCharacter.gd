extends CharacterBody2D
class_name BaseCharacter

# Character data
@export var character_data: CharacterData

# Player identification (1 or 2) - 0 means auto-detect
@export var player_number: int = 0

# Movement direction tracking
var movement_direction: float = 0.0  # -1 = left, 0 = not moving, 1 = right

# Current state
var current_health: int = 100

# Combat meters
var special_meter: float = 0.0
var ultimate_meter: float = 0.0

# Combo system
var combo_count: int = 0
var combo_timer: float = 0.0

# State machine
enum CharacterState {IDLE, MOVING, ATTACKING_LIGHT, ATTACKING_HEAVY, BLOCKING, SPECIAL_ATTACK, ULTIMATE_ATTACK, HIT, DEFEAT}
var current_state = CharacterState.IDLE

# Reference to opponent
var opponent: BaseCharacter = null

# Animation and visual nodes
var sprite: AnimatedSprite2D
var audio_player: AudioStreamPlayer2D

# Signals
signal health_changed(new_health)
signal special_meter_changed(new_value)
signal ultimate_meter_changed(new_value)
signal combo_changed(new_combo)
signal animation_finished(anim_name)

func _ready():
	# If no character data is assigned, create a default one
	if not character_data:
		character_data = CharacterData.new()
	
	# Auto-detect player number if not set
	if player_number == 0:
		call_deferred("auto_detect_player_number")
	
	# Initialize health and meters
	current_health = character_data.max_health
	special_meter = 0.0
	ultimate_meter = 0.0
	
	# Setup character visuals
	setup_visuals()
	
	# Setup audio
	setup_audio()
	
	# Create collision shape if needed
	if not has_node("CollisionShape2D"):
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(50, 100)
		collision.shape = shape
		add_child(collision)
	
	# Create hit box for attacks
	if not has_node("AttackArea"):
		var attack_area = Area2D.new()
		attack_area.name = "AttackArea"
		
		var attack_collision = CollisionShape2D.new()
		var attack_shape = RectangleShape2D.new()
		attack_shape.size = Vector2(70, 100)
		attack_collision.shape = attack_shape
		attack_collision.position.x = 60  # Place in front of character
		
		attack_area.add_child(attack_collision)
		attack_area.monitoring = false  # Start disabled, enable during attacks
		add_child(attack_area)

func setup_visuals():
	# Remove any existing sprites
	if has_node("DebugSprite"):
		$DebugSprite.queue_free()
	
	if has_node("Sprite"):
		$Sprite.queue_free()
	
	# Create animated sprite
	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	add_child(sprite)
	
	# Connect animation finished signal
	sprite.connect("animation_finished", _on_animation_finished)
	
	# Check if we have any animation frames and create SpriteFrames
	sprite.sprite_frames = SpriteFrames.new()
	var has_animations = false
	
	# Only add animations that actually exist
	if character_data.idle_animation:
		add_animation("idle", character_data.idle_animation)
		has_animations = true
		
	if character_data.run_forward_animation:
		add_animation("run_forward", character_data.run_forward_animation)
		has_animations = true
		
	if character_data.run_backward_animation:
		add_animation("run_backward", character_data.run_backward_animation)
		has_animations = true
		
	if character_data.light_attack_animation:
		add_animation("light_attack", character_data.light_attack_animation)
		has_animations = true
		
	if character_data.heavy_attack_animation:
		add_animation("heavy_attack", character_data.heavy_attack_animation)
		has_animations = true
		
	if character_data.block_animation:
		add_animation("block", character_data.block_animation)
		has_animations = true
		
	if character_data.hit_animation:
		add_animation("hit", character_data.hit_animation)
		has_animations = true
		
	if character_data.special_attack_animation:
		add_animation("special_attack", character_data.special_attack_animation)
		has_animations = true
		
	if character_data.ultimate_attack_animation:
		add_animation("ultimate_attack", character_data.ultimate_attack_animation)
		has_animations = true
		
	if character_data.defeat_animation:
		add_animation("defeat", character_data.defeat_animation)
		has_animations = true
	
	# Start with the first available animation
	if has_animations:
		if sprite.sprite_frames.has_animation("idle"):
			play_animation("idle")
		else:
			# Play the first available animation
			var available_animations = sprite.sprite_frames.get_animation_names()
			if available_animations.size() > 0:
				play_animation(available_animations[0])
		
		# Set anchor point to bottom center after animations are loaded
		set_sprite_anchor_bottom()
	
	if not has_animations:
		# No animations provided, create a debug rectangle
		var img = Image.create(50, 100, false, Image.FORMAT_RGBA8)
		img.fill(character_data.color)
		var tex = ImageTexture.create_from_image(img)
		
		# Create SpriteFrames for the debug sprite
		sprite.sprite_frames = SpriteFrames.new()
		sprite.sprite_frames.add_animation("debug")
		sprite.sprite_frames.add_frame("debug", tex)
		sprite.play("debug")
		sprite.flip_h = (player_number == 1)
		
		# Set anchor point for debug sprite
		set_sprite_anchor_bottom()

func set_sprite_anchor_bottom():
	if not sprite:
		return
	
	# Reset position
	sprite.position.y = 0
	
	# Get current frame size to set proper offset
	if sprite.sprite_frames and sprite.animation != "":
		var current_frame = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if current_frame:
			var frame_width = current_frame.get_width()
			var frame_height = current_frame.get_height()
			
			# Set Y offset so bottom of sprite is at node position
			sprite.offset.y = -frame_height / 2
			
			# Set X offset based on player number (anchor to back edge)
			if player_number == 1:
				# Player 1: anchor to left edge (back)
				sprite.offset.x = frame_width / 2
			else:
				# Player 2: anchor to right edge (back)  
				sprite.offset.x = -frame_width / 2
		else:
			# Fallback values
			sprite.offset.y = -50
			if player_number == 1:
				sprite.offset.x = 25  # Half of debug width
			else:
				sprite.offset.x = -25
	else:
		# For debug sprite
		sprite.offset.y = -50
		if player_number == 1:
			sprite.offset.x = 25  # Half of debug width (50/2)
		else:
			sprite.offset.x = -25

func get_movement_animation() -> String:
	if movement_direction == 0:
		return "idle"
	
	# Determine if moving forward or backward based on player number
	var is_moving_forward: bool
	
	if player_number == 1:
		# Player 1: right is forward, left is backward
		is_moving_forward = (movement_direction > 0)
	else:
		# Player 2: left is forward, right is backward
		is_moving_forward = (movement_direction < 0)
	
	if is_moving_forward:
		return "run_forward" if sprite.sprite_frames.has_animation("run_forward") else "idle"
	else:
		return "run_backward" if sprite.sprite_frames.has_animation("run_backward") else "idle"

func set_movement_direction(direction: float):
	movement_direction = direction

# Animation control with scaling
func play_animation(animation_name: String):
	if not sprite or not sprite.sprite_frames:
		return
		
	if not sprite.sprite_frames.has_animation(animation_name):
		return
	
	# Play the animation
	sprite.play(animation_name)
	
	# Apply the appropriate scale
	var target_scale = character_data.get_animation_scale(animation_name)
	sprite.scale = target_scale
	
	# Simple flipping: Player 1 is flipped, Player 2 is not
	sprite.flip_h = (player_number == 1)
	
	# Update anchor point for the new animation
	call_deferred("set_sprite_anchor_bottom")

# Smooth animation transition with scaling
func play_animation_smooth(animation_name: String, transition_duration: float = 0.1):
	if not sprite or not sprite.sprite_frames:
		return
		
	if not sprite.sprite_frames.has_animation(animation_name):
		return
	
	# Get target scale
	var target_scale = character_data.get_animation_scale(animation_name)
	
	# Create a tween for smooth scaling transition
	var tween = create_tween()
	tween.parallel().tween_property(sprite, "scale", target_scale, transition_duration)
	
	# Play the animation
	sprite.play(animation_name)
	
	# Simple flipping: Player 1 is flipped, Player 2 is not
	sprite.flip_h = (player_number == 1)
	
	# Update anchor point for the new animation
	call_deferred("set_sprite_anchor_bottom")

func add_animation(anim_name: String, frames: SpriteFrames):
	if not frames or not sprite.sprite_frames:
		return
		
	# Check if the source SpriteFrames has any animations
	var source_animations = frames.get_animation_names()
	if source_animations.size() == 0:
		return
		
	# Use the first available animation from the source
	var source_anim_name = source_animations[0]
	
	# Check if source animation has any frames
	if frames.get_frame_count(source_anim_name) == 0:
		return
		
	# Add animation to our sprite frames
	if not sprite.sprite_frames.has_animation(anim_name):
		sprite.sprite_frames.add_animation(anim_name)
		
	# Copy frames from the source animation
	for i in range(frames.get_frame_count(source_anim_name)):
		var frame_texture = frames.get_frame_texture(source_anim_name, i)
		if frame_texture:
			sprite.sprite_frames.add_frame(anim_name, frame_texture)
	
	# Only set properties if we successfully added frames
	if sprite.sprite_frames.get_frame_count(anim_name) > 0:
		sprite.sprite_frames.set_animation_speed(anim_name, frames.get_animation_speed(source_anim_name))
		
		# FORCE attack animations to NOT loop
		if "attack" in anim_name or anim_name == "hit" or anim_name == "defeat":
			sprite.sprite_frames.set_animation_loop(anim_name, false)
		else:
			sprite.sprite_frames.set_animation_loop(anim_name, frames.get_animation_loop(source_anim_name))

func auto_detect_player_number():
	# Method 1: Check position (assumes player 1 starts on left, player 2 on right)
	var viewport_center = get_viewport().get_visible_rect().size.x / 2
	if global_position.x < viewport_center:
		player_number = 1
	else:
		player_number = 2
	
	# Method 2: Check node name if it contains player info
	if "player1" in name.to_lower() or "p1" in name.to_lower():
		player_number = 1
	elif "player2" in name.to_lower() or "p2" in name.to_lower():
		player_number = 2
	
	# Default to player 1 if we still can't determine
	if player_number == 0:
		player_number = 1
	
	# Apply flipping immediately after detection
	if sprite:
		sprite.flip_h = (player_number == 1)
	if has_node("DebugSprite"):
		$DebugSprite.flip_h = (player_number == 1)

func setup_audio():
	# Create audio player if needed
	if not has_node("AudioPlayer"):
		audio_player = AudioStreamPlayer2D.new()
		audio_player.name = "AudioPlayer"
		add_child(audio_player)
	else:
		audio_player = $AudioPlayer

func _physics_process(delta):
	# Update combo timer
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0
			emit_signal("combo_changed", combo_count)
	
	# Passive ultimate meter charge
	charge_ultimate_meter(character_data.ultimate_meter_gain_per_second * delta)
	
	# Process current state
	match current_state:
		CharacterState.IDLE:
			# Check if we should be moving based on velocity
			if abs(velocity.x) > 10:  # Small threshold to avoid jitter
				current_state = CharacterState.MOVING
				movement_direction = sign(velocity.x)
			else:
				movement_direction = 0.0
				# Only try to play idle if it exists AND we're not already playing it
				if sprite and sprite.sprite_frames:
					if sprite.sprite_frames.has_animation("idle") and sprite.animation != "idle":
						play_animation("idle")
					elif not sprite.sprite_frames.has_animation("idle"):
						# No idle animation available - just stop whatever is playing
						if sprite.animation != "":
							sprite.stop()
		CharacterState.MOVING:
			# Check if we should stop moving
			if abs(velocity.x) <= 10:  # Small threshold to avoid jitter
				current_state = CharacterState.IDLE
				movement_direction = 0.0
			else:
				movement_direction = sign(velocity.x)
				var target_anim = get_movement_animation()
				if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(target_anim):
					if sprite.animation != target_anim:
						play_animation(target_anim)
		# Other states are controlled by their respective functions
	
	move_and_slide()

# Movement control functions
func move_left():
	if can_move():
		velocity.x = -character_data.move_speed
		current_state = CharacterState.MOVING

func move_right():
	if can_move():
		velocity.x = character_data.move_speed
		current_state = CharacterState.MOVING

func stop_moving():
	velocity.x = 0
	if current_state == CharacterState.MOVING:
		current_state = CharacterState.IDLE

func can_move():
	return current_state == CharacterState.IDLE or current_state == CharacterState.MOVING

# Basic attacks
func light_attack():
	if can_attack():
		current_state = CharacterState.ATTACKING_LIGHT
		
		# Play animation if available
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("light_attack"):
			play_animation("light_attack")
		else:
			current_state = CharacterState.IDLE
			return
		
		# Play sound effect if available
		play_sound(character_data.light_attack_sound)
		
		# Enable attack area
		var attack_area = get_node("AttackArea")
		attack_area.monitoring = true
		
		# Check for hit immediately
		if opponent and is_opponent_in_attack_range(character_data.light_attack_range):
			var damage = character_data.light_attack_damage
			var blocked = opponent.is_blocking()
			opponent.take_damage(damage, false)
			
			if not blocked:
				register_hit()

func heavy_attack():
	if can_attack():
		current_state = CharacterState.ATTACKING_HEAVY
		
		# Play animation if available
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("heavy_attack"):
			play_animation("heavy_attack")
		else:
			current_state = CharacterState.IDLE
			return
		
		# Play sound effect if available
		play_sound(character_data.heavy_attack_sound)
		
		# Enable attack area
		var attack_area = get_node("AttackArea")
		attack_area.monitoring = true
		
		# Check for hit immediately
		if opponent and is_opponent_in_attack_range(character_data.heavy_attack_range):
			var damage = character_data.heavy_attack_damage
			var blocked = opponent.is_blocking()
			opponent.take_damage(damage, false)
			
			if not blocked:
				register_hit()

func block():
	if can_block():
		current_state = CharacterState.BLOCKING
		
		# Play animation if available
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("block"):
			play_animation("block")
		
		# Play sound effect if available
		play_sound(character_data.block_sound)

func stop_blocking():
	if current_state == CharacterState.BLOCKING:
		current_state = CharacterState.IDLE
		
		# Return to idle animation
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			play_animation("idle")

func special_attack():
	if can_use_special():
		current_state = CharacterState.SPECIAL_ATTACK
		
		# Play animation if available
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("special_attack"):
			play_animation("special_attack")
		else:
			current_state = CharacterState.IDLE
			return
		
		# Play sound effect if available
		play_sound(character_data.special_attack_sound)
		
		# Use up special meter
		special_meter = 0
		emit_signal("special_meter_changed", special_meter)
		
		# Enable attack area
		var attack_area = get_node("AttackArea")
		attack_area.monitoring = true
		
		# Check for hit immediately
		if opponent and is_opponent_in_attack_range(character_data.special_attack_range):
			var damage = character_data.special_attack_damage
			var blocked = opponent.is_blocking()
			opponent.take_damage(damage, true)
			
			if not blocked:
				register_hit()

func ultimate_attack():
	if can_use_ultimate():
		current_state = CharacterState.ULTIMATE_ATTACK
		
		# Play animation if available
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("ultimate_attack"):
			play_animation("ultimate_attack")
		else:
			current_state = CharacterState.IDLE
			return
		
		# Play sound effect if available
		play_sound(character_data.ultimate_attack_sound)
		
		# Use up ultimate meter
		ultimate_meter = 0
		emit_signal("ultimate_meter_changed", ultimate_meter)
		
		# Enable attack area
		var attack_area = get_node("AttackArea")
		attack_area.monitoring = true
		
		# Check for hit immediately
		if opponent and is_opponent_in_attack_range(character_data.ultimate_attack_range):
			var damage = character_data.ultimate_attack_damage
			opponent.take_damage(damage, true)
			register_hit()

# State checks
func can_attack():
	return current_state == CharacterState.IDLE or current_state == CharacterState.MOVING

func can_block():
	return current_state == CharacterState.IDLE or current_state == CharacterState.MOVING

func can_use_special():
	return special_meter >= character_data.special_meter_max and (current_state == CharacterState.IDLE or current_state == CharacterState.MOVING)

func can_use_ultimate():
	return ultimate_meter >= character_data.ultimate_meter_max and (current_state == CharacterState.IDLE or current_state == CharacterState.MOVING)

func is_blocking():
	return current_state == CharacterState.BLOCKING

# Helper functions
func is_opponent_in_attack_range(attack_range: float) -> bool:
	if not opponent:
		print("No opponent found")
		return false
	
	var my_x = global_position.x
	var opponent_x = opponent.global_position.x
	
	
	if player_number == 1:
		# Player 1: hitbox extends rightward from character position
		var hit = opponent_x >= my_x and opponent_x <= (my_x + attack_range)
		print("Player 1 check: opponent_x >= ", my_x, " and opponent_x <= ", (my_x + attack_range), " = ", hit)
		return hit
	else:
		# Player 2: hitbox extends leftward from character position  
		var hit = opponent_x <= my_x and opponent_x >= (my_x - attack_range)
		print("Player 2 check: opponent_x <= ", my_x, " and opponent_x >= ", (my_x - attack_range), " = ", hit)
		return hit

# Legacy function for backward compatibility
func is_opponent_in_range():
	return is_opponent_in_attack_range(120.0)  # Default range

# Combat mechanics
func take_damage(damage_amount, ignore_block):
	var blocked = is_blocking() and not ignore_block
	
	if blocked:
		damage_amount = damage_amount * 0.2  # 80% damage reduction when blocking
		play_sound(character_data.block_sound)
	else:
		play_sound(character_data.hit_sound)
	
	current_health -= damage_amount
	current_health = max(0, current_health)
	
	emit_signal("health_changed", current_health)
	
	if current_health <= 0:
		current_state = CharacterState.DEFEAT
		
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("defeat"):
			play_animation("defeat")
			
		play_sound(character_data.defeat_sound)
	elif not blocked:
		current_state = CharacterState.HIT
		
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("hit"):
			play_animation("hit")
	
	return not blocked

func register_hit():
	combo_count += 1
	combo_timer = character_data.combo_timeout
	emit_signal("combo_changed", combo_count)
	
	charge_special_meter(character_data.special_meter_gain_per_hit)
	
	var combo_bonus = combo_count * 2.0
	charge_ultimate_meter(combo_bonus)

func charge_special_meter(amount):
	special_meter += amount
	special_meter = min(special_meter, character_data.special_meter_max)
	emit_signal("special_meter_changed", special_meter)

func charge_ultimate_meter(amount):
	ultimate_meter += amount
	ultimate_meter = min(ultimate_meter, character_data.ultimate_meter_max)
	emit_signal("ultimate_meter_changed", ultimate_meter)

# Animation handling
func _on_animation_finished():
	if not sprite:
		return
		
	var anim_name = sprite.animation
	
	match current_state:
		CharacterState.ATTACKING_LIGHT:
			if anim_name == "light_attack":
				current_state = CharacterState.IDLE
				$AttackArea.monitoring = false
				
		CharacterState.ATTACKING_HEAVY:
			if anim_name == "heavy_attack":
				current_state = CharacterState.IDLE
				$AttackArea.monitoring = false
				
		CharacterState.SPECIAL_ATTACK:
			if anim_name == "special_attack":
				current_state = CharacterState.IDLE
				$AttackArea.monitoring = false
				
		CharacterState.ULTIMATE_ATTACK:
			if anim_name == "ultimate_attack":
				current_state = CharacterState.IDLE
				$AttackArea.monitoring = false
				
		CharacterState.HIT:
			if anim_name == "hit":
				current_state = CharacterState.IDLE
	
	# Don't automatically play idle here - let _physics_process handle it
	emit_signal("animation_finished", anim_name)

# Sound handling
func play_sound(sound: AudioStream):
	if sound and audio_player:
		audio_player.stream = sound
		audio_player.play()

# This method should be overridden by player/AI controllers
func handle_input():
	pass
