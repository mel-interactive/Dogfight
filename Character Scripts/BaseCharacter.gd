extends CharacterBody2D
class_name BaseCharacter

# Character data
@export var character_data: CharacterData

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

# Direction the character is facing (1 = right, -1 = left)
var facing_direction: int = 1

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
	# Remove any existing sprite
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
	
	# Check if we have animation frames
	if character_data.idle_animation:
		# Set up sprite frames
		add_animation("idle", character_data.idle_animation)
		add_animation("run", character_data.run_animation)
		add_animation("light_attack", character_data.light_attack_animation)
		add_animation("heavy_attack", character_data.heavy_attack_animation)
		add_animation("block", character_data.block_animation)
		add_animation("hit", character_data.hit_animation)
		add_animation("special_attack", character_data.special_attack_animation)
		add_animation("ultimate_attack", character_data.ultimate_attack_animation)
		add_animation("defeat", character_data.defeat_animation)
		
		# Start with idle animation
		sprite.play("idle")
	else:
		# No animations provided, create a debug rectangle
		var img = Image.create(50, 100, false, Image.FORMAT_RGBA8)
		img.fill(character_data.color)
		var tex = ImageTexture.create_from_image(img)
		
		# Create a simple sprite for debug
		var debug_sprite = Sprite2D.new()
		debug_sprite.name = "DebugSprite"
		debug_sprite.texture = tex
		add_child(debug_sprite)

func add_animation(anim_name: String, frames: SpriteFrames):
	if frames:
		if not sprite.sprite_frames:
			sprite.sprite_frames = SpriteFrames.new()
		
		if not sprite.sprite_frames.has_animation(anim_name):
			sprite.sprite_frames.add_animation(anim_name)
			
		# Copy frames from the character data
		for i in range(frames.get_frame_count("default")):
			sprite.sprite_frames.add_frame(anim_name, frames.get_frame("default", i))
		
		# Set animation speed
		sprite.sprite_frames.set_animation_speed(anim_name, frames.get_animation_speed("default"))
		sprite.sprite_frames.set_animation_loop(anim_name, frames.get_animation_loop("default"))

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
			# Idle animation
			if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
				if sprite.animation != "idle":
					sprite.play("idle")
		CharacterState.MOVING:
			# Movement handled by input or AI controller
			if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("run"):
				if sprite.animation != "run":
					sprite.play("run")
		# Other states are controlled by their respective functions
	
	move_and_slide()

# Basic attacks
func light_attack():
	if can_attack():
		current_state = CharacterState.ATTACKING_LIGHT
		
		# Play animation if available
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("light_attack"):
			sprite.play("light_attack")
		
		# Play sound effect if available
		play_sound(character_data.light_attack_sound)
		
		# Debug attack: enable attack area
		var attack_area = get_node("AttackArea")
		attack_area.monitoring = true
		
		# Check if opponent is in range and not blocking
		if opponent and is_opponent_in_range():
			var damage = character_data.light_attack_damage
			# Must use await when calling take_damage
			var hit_successful = await opponent.take_damage(damage, false)
			
			if hit_successful:
				register_hit()
		
		# If no animation, use timer
		if not sprite or not sprite.sprite_frames or not sprite.sprite_frames.has_animation("light_attack"):
			# Disable attack area after a short delay
			await get_tree().create_timer(character_data.light_attack_duration).timeout
			attack_area.monitoring = false
			
			# Return to idle state
			current_state = CharacterState.IDLE

func heavy_attack():
	if can_attack():
		current_state = CharacterState.ATTACKING_HEAVY
		
		# Play animation if available
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("heavy_attack"):
			sprite.play("heavy_attack")
		
		# Play sound effect if available
		play_sound(character_data.heavy_attack_sound)
		
		# Debug attack: enable attack area
		var attack_area = get_node("AttackArea")
		attack_area.monitoring = true
		
		# Check if opponent is in range and not blocking
		if opponent and is_opponent_in_range():
			var damage = character_data.heavy_attack_damage
			# Must use await when calling take_damage
			var hit_successful = await opponent.take_damage(damage, false)
			
			if hit_successful:
				register_hit()
		
		# If no animation, use timer
		if not sprite or not sprite.sprite_frames or not sprite.sprite_frames.has_animation("heavy_attack"):
			# Disable attack area after a short delay
			await get_tree().create_timer(character_data.heavy_attack_duration).timeout
			attack_area.monitoring = false
			
			# Return to idle state
			current_state = CharacterState.IDLE

func block():
	if can_block():
		current_state = CharacterState.BLOCKING
		
		# Play animation if available
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("block"):
			sprite.play("block")
		
		# Play sound effect if available
		play_sound(character_data.block_sound)

func stop_blocking():
	if current_state == CharacterState.BLOCKING:
		current_state = CharacterState.IDLE
		
		# Return to idle animation
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")

func special_attack():
	if can_use_special():
		current_state = CharacterState.SPECIAL_ATTACK
		
		# Play animation if available
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("special_attack"):
			sprite.play("special_attack")
		
		# Play sound effect if available
		play_sound(character_data.special_attack_sound)
		
		# Use up special meter
		special_meter = 0
		emit_signal("special_meter_changed", special_meter)
		
		# Debug attack: enable attack area
		var attack_area = get_node("AttackArea")
		attack_area.monitoring = true
		
		# Check if opponent is in range
		if opponent and is_opponent_in_range():
			var damage = character_data.special_attack_damage
			# Special attacks partially bypass blocks
			# Must use await when calling take_damage
			var hit_successful = await opponent.take_damage(damage, true)
			
			if hit_successful:
				register_hit()
		
		# If no animation, use timer
		if not sprite or not sprite.sprite_frames or not sprite.sprite_frames.has_animation("special_attack"):
			# Disable attack area after a short delay
			await get_tree().create_timer(character_data.special_attack_duration).timeout
			attack_area.monitoring = false
			
			# Return to idle state
			current_state = CharacterState.IDLE

func ultimate_attack():
	if can_use_ultimate():
		current_state = CharacterState.ULTIMATE_ATTACK
		
		# Play animation if available
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("ultimate_attack"):
			sprite.play("ultimate_attack")
		
		# Play sound effect if available
		play_sound(character_data.ultimate_attack_sound)
		
		# Use up ultimate meter
		ultimate_meter = 0
		emit_signal("ultimate_meter_changed", ultimate_meter)
		
		# Debug attack: enable attack area
		var attack_area = get_node("AttackArea")
		attack_area.monitoring = true
		
		# Check if opponent is in range
		if opponent and is_opponent_in_range():
			var damage = character_data.ultimate_attack_damage
			# Ultimate attacks bypass blocks
			# Must use await when calling take_damage
			var hit_successful = await opponent.take_damage(damage, true)
			
			if hit_successful:
				register_hit()
		
		# If no animation, use timer
		if not sprite or not sprite.sprite_frames or not sprite.sprite_frames.has_animation("ultimate_attack"):
			# Disable attack area after a short delay
			await get_tree().create_timer(character_data.ultimate_attack_duration).timeout
			attack_area.monitoring = false
			
			# Return to idle state
			current_state = CharacterState.IDLE

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
func is_opponent_in_range():
	# Simple distance check for debug purposes
	if not opponent:
		return false
	
	var attack_distance = 120  # Adjust based on testing
	return abs(global_position.x - opponent.global_position.x) < attack_distance

# Combat mechanics
func take_damage(damage_amount, ignore_block):
	# Check if attack is blocked
	var blocked = is_blocking() and not ignore_block
	
	if blocked:
		# Reduce damage when blocking
		damage_amount = damage_amount * 0.2  # 80% damage reduction when blocking
		
		# Play block sound if available
		play_sound(character_data.block_sound)
	else:
		# Play hit sound if available
		play_sound(character_data.hit_sound)
	
	current_health -= damage_amount
	current_health = max(0, current_health)
	
	emit_signal("health_changed", current_health)
	
	if current_health <= 0:
		current_state = CharacterState.DEFEAT
		
		# Play defeat animation if available
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("defeat"):
			sprite.play("defeat")
			
		# Play defeat sound if available
		play_sound(character_data.defeat_sound)
	elif not blocked:
		current_state = CharacterState.HIT
		
		# Play hit animation if available
		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("hit"):
			sprite.play("hit")
		
		# If no animation, use timer
		if not sprite or not sprite.sprite_frames or not sprite.sprite_frames.has_animation("hit"):
			# Return to idle after a short stun
			await get_tree().create_timer(character_data.hit_stun_duration).timeout
			if current_state == CharacterState.HIT:  # Make sure we're still in hit state
				current_state = CharacterState.IDLE
	
	return not blocked  # Return whether hit was successful (not blocked)

func register_hit():
	# Increase combo
	combo_count += 1
	combo_timer = character_data.combo_timeout
	emit_signal("combo_changed", combo_count)
	
	# Charge special meter
	charge_special_meter(character_data.special_meter_gain_per_hit)
	
	# Combo increases ultimate charge rate
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

# Direction control
func face_opponent():
	if opponent:
		if global_position.x < opponent.global_position.x:
			facing_direction = 1
		else:
			facing_direction = -1
		
		# Flip sprite based on direction
		if sprite:
			sprite.flip_h = (facing_direction == -1)
		elif has_node("DebugSprite"):
			$DebugSprite.flip_h = (facing_direction == -1)
			
		# Flip attack area
		$AttackArea.scale.x = facing_direction

# Animation handling
func _on_animation_finished():
	# Called when an animation finishes
	if sprite:
		var anim_name = sprite.animation
		
		match current_state:
			CharacterState.ATTACKING_LIGHT:
				if anim_name == "light_attack":
					current_state = CharacterState.IDLE
					$AttackArea.monitoring = false
					sprite.play("idle")
					
			CharacterState.ATTACKING_HEAVY:
				if anim_name == "heavy_attack":
					current_state = CharacterState.IDLE
					$AttackArea.monitoring = false
					sprite.play("idle")
					
			CharacterState.SPECIAL_ATTACK:
				if anim_name == "special_attack":
					current_state = CharacterState.IDLE
					$AttackArea.monitoring = false
					sprite.play("idle")
					
			CharacterState.ULTIMATE_ATTACK:
				if anim_name == "ultimate_attack":
					current_state = CharacterState.IDLE
					$AttackArea.monitoring = false
					sprite.play("idle")
					
			CharacterState.HIT:
				if anim_name == "hit":
					current_state = CharacterState.IDLE
					sprite.play("idle")
	
	# Emit animation finished signal
	emit_signal("animation_finished", sprite.animation if sprite else "")

# Sound handling
func play_sound(sound: AudioStream):
	if sound and audio_player:
		audio_player.stream = sound
		audio_player.play()

# This method should be overridden by player/AI controllers
func handle_input():
	pass
