extends CharacterBody2D
class_name BaseCharacter

# Character data
@export var character_data: CharacterData

# Player identification (1 or 2) - 0 means auto-detect
@export var player_number: int = 0

# Movement direction tracking
var movement_direction: float = 0.0

# Current state
var current_health: int = 100

# Combat meters
var special_meter: float = 0.0
var ultimate_meter: float = 0.0

# Combo system
var combo_count: int = 0
var combo_timer: float = 0.0

# Combat timing
var attack_timer: float = 0.0
var attack_hit_applied: bool = false

# State machine
enum CharacterState {IDLE, MOVING, ATTACKING_LIGHT, ATTACKING_HEAVY, BLOCKING, SPECIAL_ATTACK, ULTIMATE_ATTACK, HIT, DEFEAT}
var current_state = CharacterState.IDLE

# Reference to opponent
var opponent: BaseCharacter = null

# Animation and visual nodes
var sprite: AnimatedSprite2D
var custom_animation_sprites: Array[AnimatedSprite2D] = []  # For custom animations
var audio_player: AudioStreamPlayer2D

# Simple shake variables
var original_sprite_position: Vector2
var shake_offset: Vector2 = Vector2.ZERO

# Signals
signal health_changed(new_health)
signal special_meter_changed(new_value)
signal ultimate_meter_changed(new_value)
signal combo_changed(new_combo)
signal animation_finished(anim_name)

func _ready():
	if not character_data:
		character_data = CharacterData.new()
	
	if player_number == 0:
		call_deferred("auto_detect_player_number")
	
	current_health = character_data.max_health
	special_meter = 0.0
	ultimate_meter = 0.0
	
	setup_visuals()
	setup_audio()
	setup_collision()
	setup_attack_area()
	
	# Store original sprite position for shake effect
	if sprite:
		original_sprite_position = sprite.position

func setup_visuals():
	# Clean up existing sprites
	if has_node("DebugSprite"):
		$DebugSprite.queue_free()
	if has_node("Sprite"):
		$Sprite.queue_free()
	
	# Clear custom animation sprites
	for custom_sprite in custom_animation_sprites:
		if is_instance_valid(custom_sprite):
			custom_sprite.queue_free()
	custom_animation_sprites.clear()
	
	# Create main animated sprite
	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.z_index = 0  # Base layer for character sprites
	add_child(sprite)
	sprite.connect("animation_finished", _on_animation_finished)
	
	# Setup base animations
	setup_base_animations()
	
	# Setup custom animations
	setup_custom_animations()

func setup_base_animations():
	sprite.sprite_frames = SpriteFrames.new()
	var has_animations = false
	
	# Add base animations
	var base_animations = [
		"idle", "run_forward", "run_backward", "light_attack",
		"heavy_attack", "block", "hit", "special_attack",
		"ultimate_attack", "defeat"
	]
	
	for anim_name in base_animations:
		if character_data.has_base_animation(anim_name):
			var base_anim = character_data.get_base_animation(anim_name)
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
	for i in range(character_data.custom_animations.size()):
		var custom_anim = character_data.custom_animations[i]
		if not custom_anim.animation_frames:
			continue
			
		var custom_sprite = AnimatedSprite2D.new()
		custom_sprite.name = "CustomSprite" + str(i)
		custom_sprite.visible = false
		custom_sprite.z_index = 10  # Set higher z_index to appear above main sprite
		add_child(custom_sprite)
		
		# Setup the animation
		custom_sprite.sprite_frames = custom_anim.animation_frames
		custom_sprite.connect("animation_finished", _on_custom_animation_finished.bind(i))
		
		custom_animation_sprites.append(custom_sprite)

func create_debug_sprite():
	var img = Image.create(50, 100, false, Image.FORMAT_RGBA8)
	img.fill(character_data.color)
	var tex = ImageTexture.create_from_image(img)
	
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.add_animation("debug")
	sprite.sprite_frames.add_frame("debug", tex)
	sprite.play("debug")
	sprite.flip_h = (player_number == 1)
	set_sprite_anchor_bottom()

func setup_collision():
	if not has_node("CollisionShape2D"):
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(50, 100)
		collision.shape = shape
		add_child(collision)

func setup_attack_area():
	if not has_node("AttackArea"):
		var attack_area = Area2D.new()
		attack_area.name = "AttackArea"
		
		var attack_collision = CollisionShape2D.new()
		var attack_shape = RectangleShape2D.new()
		attack_shape.size = Vector2(70, 100)
		attack_collision.shape = attack_shape
		attack_collision.position.x = 60
		
		attack_area.add_child(attack_collision)
		attack_area.monitoring = false
		add_child(attack_area)

func setup_audio():
	if not has_node("AudioPlayer"):
		audio_player = AudioStreamPlayer2D.new()
		audio_player.name = "AudioPlayer"
		add_child(audio_player)
	else:
		audio_player = $AudioPlayer

func set_sprite_anchor_bottom():
	if not sprite:
		return
	
	sprite.position.y = 0
	
	if sprite.sprite_frames and sprite.animation != "":
		var current_frame = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if current_frame:
			var frame_width = current_frame.get_width()
			var frame_height = current_frame.get_height()
			
			sprite.offset.y = -frame_height / 2
			
			if player_number == 1:
				sprite.offset.x = frame_width / 2
			else:
				sprite.offset.x = -frame_width / 2
		else:
			sprite.offset.y = -50
			sprite.offset.x = 25 if player_number == 1 else -25
	else:
		sprite.offset.y = -50
		sprite.offset.x = 25 if player_number == 1 else -25

# Simple shake function - just moves sprite once
func do_simple_shake():
	if not sprite:
		return
	
	# Move sprite backwards based on player number (taking a hit)
	var backward_x = -10 if player_number == 1 else 10  # Player 1 goes left, Player 2 goes right
	shake_offset = Vector2(backward_x, 0)
	sprite.position = original_sprite_position + shake_offset
	
	# Flash sprite closer to white
	sprite.modulate = Color(1.5, 1.5, 1.5, 1.0)  # Brighten towards white
	
	# Return to normal position and color after a brief moment
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.1
	timer.one_shot = true
	timer.timeout.connect(_reset_sprite_position)
	timer.timeout.connect(timer.queue_free)
	timer.start()

# Reset sprite position
func _reset_sprite_position():
	if sprite:
		sprite.position = original_sprite_position
		sprite.modulate = Color.WHITE  # Reset color back to normal
		shake_offset = Vector2.ZERO

# Play base animation
func play_animation(animation_name: String):
	if not sprite or not sprite.sprite_frames:
		return
		
	if not sprite.sprite_frames.has_animation(animation_name):
		return
	
	sprite.play(animation_name)
	
	var target_scale = character_data.get_animation_scale(animation_name)
	sprite.scale = target_scale
	sprite.flip_h = (player_number == 1)
	
	call_deferred("set_sprite_anchor_bottom")
	
	# Play all custom animations bound to this base animation
	play_custom_animations_for_action(animation_name)

# Play custom animations bound to a specific action
func play_custom_animations_for_action(action_name: String):
	var bound_animations = character_data.get_animations_for_action(action_name)
	
	for i in range(bound_animations.size()):
		var custom_anim = bound_animations[i]
		
		# Find the sprite index in our custom_animation_sprites array
		var sprite_index = character_data.custom_animations.find(custom_anim)
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
		custom_sprite.scale = character_data.base_scale * custom_anim.scale
		
		# Handle flipping
		if custom_anim.flip_with_player:
			custom_sprite.flip_h = (player_number == 1)
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
		if player_number == 1:
			offset_to_use.x = -offset_to_use.x
		
		custom_sprite.global_position += offset_to_use
	else:
		# Position at screen center
		var viewport_size = get_viewport().get_visible_rect().size
		custom_sprite.global_position = Vector2(viewport_size.x / 2, viewport_size.y / 2)
		
		# Reset offset to center the sprite first
		custom_sprite.offset = Vector2.ZERO
		
		custom_sprite.global_position += custom_anim.position_offset

func _on_custom_animation_finished(sprite_index: int):
	if sprite_index < custom_animation_sprites.size():
		var custom_sprite = custom_animation_sprites[sprite_index]
		custom_sprite.visible = false

func get_movement_animation() -> String:
	if movement_direction == 0:
		return "idle"
	
	var is_moving_forward: bool
	if player_number == 1:
		is_moving_forward = (movement_direction > 0)
	else:
		is_moving_forward = (movement_direction < 0)
	
	if is_moving_forward:
		return "run_forward" if sprite.sprite_frames.has_animation("run_forward") else "idle"
	else:
		return "run_backward" if sprite.sprite_frames.has_animation("run_backward") else "idle"

func set_movement_direction(direction: float):
	movement_direction = direction

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
		
		if "attack" in anim_name or anim_name == "hit" or anim_name == "defeat":
			sprite.sprite_frames.set_animation_loop(anim_name, false)
		else:
			sprite.sprite_frames.set_animation_loop(anim_name, frames.get_animation_loop(source_anim_name))

func auto_detect_player_number():
	var viewport_center = get_viewport().get_visible_rect().size.x / 2
	if global_position.x < viewport_center:
		player_number = 1
	else:
		player_number = 2
	
	if "player1" in name.to_lower() or "p1" in name.to_lower():
		player_number = 1
	elif "player2" in name.to_lower() or "p2" in name.to_lower():
		player_number = 2
	
	if player_number == 0:
		player_number = 1
	
	if sprite:
		sprite.flip_h = (player_number == 1)
	if has_node("DebugSprite"):
		$DebugSprite.flip_h = (player_number == 1)

func _physics_process(delta):
	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0
			emit_signal("combo_changed", combo_count)
	
	charge_ultimate_meter(character_data.ultimate_meter_gain_per_second * delta)
	
	# Handle attack timing
	handle_attack_timing(delta)
	
	# Stop movement when in HIT state
	if current_state == CharacterState.HIT:
		velocity.x = 0
	
	match current_state:
		CharacterState.IDLE:
			if abs(velocity.x) > 10:
				current_state = CharacterState.MOVING
				movement_direction = sign(velocity.x)
			else:
				movement_direction = 0.0
				if sprite and sprite.sprite_frames:
					if sprite.sprite_frames.has_animation("idle") and sprite.animation != "idle":
						play_animation("idle")
					elif not sprite.sprite_frames.has_animation("idle"):
						if sprite.animation != "":
							sprite.stop()
		CharacterState.MOVING:
			if abs(velocity.x) <= 10:
				current_state = CharacterState.IDLE
				movement_direction = 0.0
			else:
				movement_direction = sign(velocity.x)
				var target_anim = get_movement_animation()
				if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(target_anim):
					if sprite.animation != target_anim:
						play_animation(target_anim)
		CharacterState.HIT:
			# Force stop movement when being hit
			velocity.x = 0
			movement_direction = 0.0
	
	# Apply movement constraints before moving
	apply_movement_constraints()
	
	move_and_slide()

# Handle attack timing using CharacterData duration values
func handle_attack_timing(delta):
	var is_attacking = (current_state == CharacterState.ATTACKING_LIGHT or 
					   current_state == CharacterState.ATTACKING_HEAVY or 
					   current_state == CharacterState.SPECIAL_ATTACK or 
					   current_state == CharacterState.ULTIMATE_ATTACK)
	
	if is_attacking:
		attack_timer += delta
		
		var hit_timing: float = 0.0
		match current_state:
			CharacterState.ATTACKING_LIGHT:
				hit_timing = character_data.light_attack_duration
			CharacterState.ATTACKING_HEAVY:
				hit_timing = character_data.heavy_attack_duration
			CharacterState.SPECIAL_ATTACK:
				hit_timing = character_data.special_attack_duration
			CharacterState.ULTIMATE_ATTACK:
				hit_timing = character_data.ultimate_attack_duration
		
		# Apply hit at the specified timing
		if attack_timer >= hit_timing and not attack_hit_applied:
			apply_attack_hit()
			attack_hit_applied = true

# Prevent players from overlapping too much or going too far offscreen
func apply_movement_constraints():
	var viewport_size = get_viewport().get_visible_rect().size
	var sprite_width = 50  # Default width, or get from sprite if available
	
	if sprite and sprite.sprite_frames and sprite.animation != "":
		var current_frame = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		if current_frame:
			sprite_width = current_frame.get_width() * sprite.scale.x
	
	# Screen boundaries (allow sprites to go halfway offscreen)
	var left_boundary = -(sprite_width * 0.5)
	var right_boundary = viewport_size.x + (sprite_width * 0.5)
	
	# Check opponent overlap constraint
	if opponent:
		var my_x = global_position.x
		var opponent_x = opponent.global_position.x
		var min_distance = sprite_width * 0.75  # Allow up to 25% overlap (75% minimum distance)
		
		# If moving towards opponent and would overlap too much
		if velocity.x > 0 and my_x < opponent_x:  # Moving right towards opponent
			var future_x = my_x + velocity.x * get_physics_process_delta_time()
			if future_x + min_distance > opponent_x:
				velocity.x = 0
		elif velocity.x < 0 and my_x > opponent_x:  # Moving left towards opponent
			var future_x = my_x + velocity.x * get_physics_process_delta_time()
			if future_x - min_distance < opponent_x:
				velocity.x = 0
	
	# Apply screen boundary constraints
	var future_x = global_position.x + velocity.x * get_physics_process_delta_time()
	
	if future_x < left_boundary:
		velocity.x = 0
		global_position.x = left_boundary
	elif future_x > right_boundary:
		velocity.x = 0
		global_position.x = right_boundary

# Movement functions
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
	return (current_state == CharacterState.IDLE or current_state == CharacterState.MOVING) and current_state != CharacterState.HIT

# Attack functions - FIXED BLOCKING LOGIC WITH TIMING
func light_attack():
	if can_attack():
		current_state = CharacterState.ATTACKING_LIGHT
		attack_timer = 0.0
		attack_hit_applied = false
		
		# Set higher z_index when attacking
		if sprite:
			sprite.z_index = 5
		
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("light_attack"):
			play_animation("light_attack")
		else:
			current_state = CharacterState.IDLE
			return
		
		play_sound(character_data.light_attack_sound)
		
		var attack_area = get_node("AttackArea")
		attack_area.monitoring = true

func heavy_attack():
	if can_attack():
		current_state = CharacterState.ATTACKING_HEAVY
		attack_timer = 0.0
		attack_hit_applied = false
		
		# Set higher z_index when attacking
		if sprite:
			sprite.z_index = 5
		
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("heavy_attack"):
			play_animation("heavy_attack")
		else:
			current_state = CharacterState.IDLE
			return
		
		play_sound(character_data.heavy_attack_sound)
		
		var attack_area = get_node("AttackArea")
		attack_area.monitoring = true

func block():
	if can_block():
		current_state = CharacterState.BLOCKING
		
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("block"):
			play_animation("block")
		
		play_sound(character_data.block_sound)

func stop_blocking():
	if current_state == CharacterState.BLOCKING:
		current_state = CharacterState.IDLE
		
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			play_animation("idle")

func special_attack():
	if can_use_special():
		current_state = CharacterState.SPECIAL_ATTACK
		attack_timer = 0.0
		attack_hit_applied = false
		
		# Set higher z_index when attacking
		if sprite:
			sprite.z_index = 5
		
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("special_attack"):
			play_animation("special_attack")
		else:
			current_state = CharacterState.IDLE
			return
		
		play_sound(character_data.special_attack_sound)
		
		special_meter = 0
		emit_signal("special_meter_changed", special_meter)
		
		var attack_area = get_node("AttackArea")
		attack_area.monitoring = true

func ultimate_attack():
	if can_use_ultimate():
		current_state = CharacterState.ULTIMATE_ATTACK
		attack_timer = 0.0
		attack_hit_applied = false
		
		# Set higher z_index when attacking
		if sprite:
			sprite.z_index = 5
		
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("ultimate_attack"):
			play_animation("ultimate_attack")
		else:
			current_state = CharacterState.IDLE
			return
		
		play_sound(character_data.ultimate_attack_sound)
		
		ultimate_meter = 0
		emit_signal("ultimate_meter_changed", ultimate_meter)
		
		var attack_area = get_node("AttackArea")
		attack_area.monitoring = true

# State checks
func can_attack():
	return (current_state == CharacterState.IDLE or current_state == CharacterState.MOVING) and current_state != CharacterState.HIT

func can_block():
	return (current_state == CharacterState.IDLE or current_state == CharacterState.MOVING) and current_state != CharacterState.HIT

func can_use_special():
	return special_meter >= character_data.special_meter_max and (current_state == CharacterState.IDLE or current_state == CharacterState.MOVING) and current_state != CharacterState.HIT

func can_use_ultimate():
	return ultimate_meter >= character_data.ultimate_meter_max and (current_state == CharacterState.IDLE or current_state == CharacterState.MOVING) and current_state != CharacterState.HIT

func is_blocking():
	return current_state == CharacterState.BLOCKING

# Helper functions
func is_opponent_in_attack_range(attack_range: float) -> bool:
	if not opponent:
		return false
	
	var my_x = global_position.x
	var opponent_x = opponent.global_position.x
	
	if player_number == 1:
		return opponent_x >= my_x and opponent_x <= (my_x + attack_range)
	else:
		return opponent_x <= my_x and opponent_x >= (my_x - attack_range)

func is_opponent_in_range():
	return is_opponent_in_attack_range(120.0)

func apply_attack_hit():
	if not opponent:
		return
	
	var damage: int = 0
	var attack_range: float = 0
	var ignore_block: bool = false
	
	match current_state:
		CharacterState.ATTACKING_LIGHT:
			damage = character_data.light_attack_damage
			attack_range = character_data.light_attack_range
			ignore_block = false
		CharacterState.ATTACKING_HEAVY:
			damage = character_data.heavy_attack_damage
			attack_range = character_data.heavy_attack_range
			ignore_block = false
		CharacterState.SPECIAL_ATTACK:
			damage = character_data.special_attack_damage
			attack_range = character_data.special_attack_range
			ignore_block = true  # Special attacks ignore blocking
		CharacterState.ULTIMATE_ATTACK:
			damage = character_data.ultimate_attack_damage
			attack_range = character_data.ultimate_attack_range
			ignore_block = true  # Ultimate attacks ignore blocking
	
	# Check if opponent is in range
	if is_opponent_in_attack_range(attack_range):
		if ignore_block:
			# Special/Ultimate attacks ignore blocking
			opponent.take_damage(damage, true)
			register_hit()
		else:
			# Normal attacks check for blocking
			var is_blocked = opponent.is_blocking()
			if is_blocked:
				# Play block sound and shake
				opponent.play_sound(opponent.character_data.block_sound)
				opponent.do_simple_shake()
			else:
				# Full damage
				opponent.take_damage(damage, false)
				register_hit()

# Combat mechanics - SIMPLIFIED TAKE_DAMAGE
func take_damage(damage_amount, ignore_block):
	# If ignore_block is true, skip all blocking logic
	if ignore_block:
		current_health -= damage_amount
		current_health = max(0, current_health)
		
		emit_signal("health_changed", current_health)
		
		if current_health <= 0:
			current_state = CharacterState.DEFEAT
			
			if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("defeat"):
				play_animation("defeat")
				
			play_sound(character_data.defeat_sound)
		else:
			current_state = CharacterState.HIT
			
			if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("hit"):
				play_animation("hit")
			
			play_sound(character_data.hit_sound)
		
		return true  # Damage was taken
	
	# Normal damage with blocking check
	var blocked = is_blocking()
	
	if blocked:
		# This shouldn't happen now since we handle blocking in attack functions
		# But kept for safety
		damage_amount = damage_amount * 0.2
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
				# Reset z_index when attack finishes
				if sprite:
					sprite.z_index = 0
				
		CharacterState.ATTACKING_HEAVY:
			if anim_name == "heavy_attack":
				current_state = CharacterState.IDLE
				$AttackArea.monitoring = false
				# Reset z_index when attack finishes
				if sprite:
					sprite.z_index = 0
				
		CharacterState.SPECIAL_ATTACK:
			if anim_name == "special_attack":
				current_state = CharacterState.IDLE
				$AttackArea.monitoring = false
				# Reset z_index when attack finishes
				if sprite:
					sprite.z_index = 0
				
		CharacterState.ULTIMATE_ATTACK:
			if anim_name == "ultimate_attack":
				current_state = CharacterState.IDLE
				$AttackArea.monitoring = false
				# Reset z_index when attack finishes
				if sprite:
					sprite.z_index = 0
				
		CharacterState.HIT:
			if anim_name == "hit":
				current_state = CharacterState.IDLE
	
	emit_signal("animation_finished", anim_name)

# Sound handling
func play_sound(sound: AudioStream):
	if sound and audio_player:
		audio_player.stream = sound
		audio_player.play()

# This method should be overridden by player/AI controllers
func handle_input():
	pass
