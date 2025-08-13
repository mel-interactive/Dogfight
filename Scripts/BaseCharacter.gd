# BaseCharacter.gd - Enhanced with reaction system
extends CharacterBody2D
class_name BaseCharacter

# Character data
@export var character_data: CharacterData
@export var player_number: int = 0

# Movement direction tracking
var movement_direction: float = 0.0

# Current state (kept for compatibility)
var current_health: int = 100

# Combat meters (kept for compatibility)
var special_meter: float = 0.0
var ultimate_meter: float = 0.0

# Combo system (kept for compatibility)
var combo_count: int = 0
var combo_timer: float = 0.0

# Legacy state enum (kept for compatibility)
enum CharacterState {IDLE, MOVING, ATTACKING_LIGHT, ATTACKING_HEAVY, BLOCKING, SPECIAL_ATTACK, ULTIMATE_ATTACK, HIT, DEFEAT}
var current_state = CharacterState.IDLE

# Reference to opponent
var opponent: BaseCharacter = null

# Animation and visual nodes (kept for compatibility)
var sprite: AnimatedSprite2D
var custom_animation_sprites: Array[AnimatedSprite2D] = []
var audio_player: AudioStreamPlayer2D

# Components
var state_machine: StateMachine
var visual_component: VisualComponent
var combat_component: CombatComponent
var movement_component: MovementComponent
var reaction_component: ReactionComponent  # NEW: Reaction component

# Signals (kept for compatibility)
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
	
	setup_components()
	setup_audio()
	setup_collision()
	setup_attack_area()
	
	# Connect state machine to update legacy current_state
	state_machine.connect("state_changed", _on_state_changed)

func setup_components():
	# Create other components first
	visual_component = VisualComponent.new()
	visual_component.name = "VisualComponent"
	add_child(visual_component)
	
	combat_component = CombatComponent.new()
	combat_component.name = "CombatComponent"
	add_child(combat_component)
	
	movement_component = MovementComponent.new()
	movement_component.name = "MovementComponent"
	add_child(movement_component)
	
	# NEW: Create reaction component
	reaction_component = ReactionComponent.new()
	reaction_component.name = "ReactionComponent"
	add_child(reaction_component)
	
	# Create state machine
	state_machine = StateMachine.new()
	state_machine.name = "StateMachine"
	add_child(state_machine)
	
	# Create states and add them to state machine
	var idle_state = IdleState.new()
	idle_state.name = "Idle"
	state_machine.add_child(idle_state)
	
	var moving_state = MovingState.new()
	moving_state.name = "Moving"
	state_machine.add_child(moving_state)
	
	var light_attack_state = LightAttackState.new()
	light_attack_state.name = "LightAttack"
	state_machine.add_child(light_attack_state)
	
	var heavy_attack_state = HeavyAttackState.new()
	heavy_attack_state.name = "HeavyAttack"
	state_machine.add_child(heavy_attack_state)
	
	var special_attack_state = SpecialAttackState.new()
	special_attack_state.name = "SpecialAttack"
	state_machine.add_child(special_attack_state)
	
	var ultimate_attack_state = UltimateAttackState.new()
	ultimate_attack_state.name = "UltimateAttack"
	state_machine.add_child(ultimate_attack_state)
	
	var blocking_state = BlockingState.new()
	blocking_state.name = "Blocking"
	state_machine.add_child(blocking_state)
	
	var hit_state = HitState.new()
	hit_state.name = "Hit"
	state_machine.add_child(hit_state)
	
	var defeat_state = DefeatState.new()
	defeat_state.name = "Defeat"
	state_machine.add_child(defeat_state)
	
	var entrance_state = EntranceState.new()
	entrance_state.name = "Entrance"
	state_machine.add_child(entrance_state)
	
	var victory_state = VictoryState.new()
	victory_state.name = "Victory"
	state_machine.add_child(victory_state)
	
	# Wait for everything to be ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Setup visuals first
	visual_component.setup_visuals()
	
	# Start in IDLE state initially
	state_machine.start("Idle")

# Updated _on_state_changed method (keeping existing functionality)
func _on_state_changed(old_state: String, new_state: String):
	match new_state:
		"Idle":
			current_state = CharacterState.IDLE
		"Moving":
			current_state = CharacterState.MOVING
		"LightAttack":
			current_state = CharacterState.ATTACKING_LIGHT
		"HeavyAttack":
			current_state = CharacterState.ATTACKING_HEAVY
		"SpecialAttack":
			current_state = CharacterState.SPECIAL_ATTACK
		"UltimateAttack":
			current_state = CharacterState.ULTIMATE_ATTACK
		"Blocking":
			current_state = CharacterState.BLOCKING
		"Hit":
			current_state = CharacterState.HIT
		"Defeat":
			current_state = CharacterState.DEFEAT
		"Entrance":
			current_state = CharacterState.IDLE
		"Victory":
			current_state = CharacterState.IDLE

# NEW: Method to trigger character-specific reaction using reaction component
func play_reaction_to_attack(attacking_character: BaseCharacter, attack_type: String) -> bool:
	if reaction_component:
		return reaction_component.play_reaction_to_attack(attacking_character, attack_type)
	return false

# NEW: Check if character has a specific reaction
func has_reaction_for_attack(attacking_character_id: String, attack_type: String) -> bool:
	if reaction_component:
		return reaction_component.has_reaction_for_attack(attacking_character_id, attack_type)
	return false

# NEW: Stop current reaction
func stop_current_reaction():
	if reaction_component:
		reaction_component.stop_reaction()

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

func auto_detect_player_number():
	var viewport_center = get_viewport().get_visible_rect().size.x / 2.0
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

# ===== SLIDING SYSTEM FOR SPECIAL/ULTIMATE ATTACKS =====

var is_sliding_to_spawn: bool = false
var slide_start_pos: Vector2
var slide_target_pos: Vector2
var slide_time: float = 0.0
var slide_total_duration: float = 0.0

func slide_to_spawn_position(duration: float):
	# Don't slide if we're the one attacking (our state handles our own sliding)
	var current_state_name = state_machine.get_current_state_name()
	if current_state_name == "SpecialAttack" or current_state_name == "UltimateAttack":
		return
	
	# Get our spawn position
	var spawn_pos = get_spawn_position()
	
	# Only slide if we're not already close to spawn position
	if global_position.distance_to(spawn_pos) > 10.0:
		is_sliding_to_spawn = true
		slide_start_pos = global_position
		slide_target_pos = spawn_pos
		slide_time = 0.0
		slide_total_duration = duration
		
		# Start speed lines for the non-attacking character
		visual_component.start_speed_lines()

func get_spawn_position() -> Vector2:
	# Try to get the spawn position from the fight scene
	var fight_scene = get_tree().current_scene
	if fight_scene.has_node("Positions/Player" + str(player_number) + "Position"):
		return fight_scene.get_node("Positions/Player" + str(player_number) + "Position").global_position
	
	# Fallback: estimate based on player number and screen width
	var viewport_size = get_viewport().get_visible_rect().size
	if player_number == 1:
		return Vector2(viewport_size.x * 0.25, global_position.y)
	else:
		return Vector2(viewport_size.x * 0.75, global_position.y)

func _physics_process(delta):
	# Handle sliding to spawn position
	if is_sliding_to_spawn:
		slide_time += delta
		var slide_progress = slide_time / slide_total_duration
		
		# Deceleration curve (ease-out)
		var eased_progress = 1.0 - pow(1.0 - slide_progress, 3.0)
		eased_progress = clamp(eased_progress, 0.0, 1.0)
		
		# Calculate slide direction for speed lines (renamed to avoid shadowing)
		var slide_direction = (slide_target_pos - slide_start_pos).normalized()
		visual_component.update_speed_lines_direction(slide_direction)
		
		# Interpolate position
		global_position = slide_start_pos.lerp(slide_target_pos, eased_progress)
		
		# Stop sliding when complete
		if slide_progress >= 1.0:
			is_sliding_to_spawn = false
			global_position = slide_target_pos
			
			# Stop speed lines
			visual_component.stop_speed_lines()
	
	# Apply movement constraints before moving (only if not sliding)
	if not is_sliding_to_spawn:
		movement_component.apply_movement_constraints()
	
	move_and_slide()

# ===== ATTACK FUNCTIONS (simplified - delegate to state machine) =====

func light_attack():
	if can_attack():
		state_machine.change_state("LightAttack")

func heavy_attack():
	if can_attack():
		state_machine.change_state("HeavyAttack")

func block():
	if can_block():
		state_machine.change_state("Blocking")

func stop_blocking():
	if state_machine.get_current_state_name() == "Blocking":
		state_machine.change_state("Idle")

func special_attack():
	if can_use_special():
		state_machine.change_state("SpecialAttack")

func ultimate_attack():
	if can_use_ultimate():
		state_machine.change_state("UltimateAttack")

# ===== STATE CHECKS =====

func can_attack():
	var current_state_name = state_machine.get_current_state_name()
	return (current_state_name == "Idle" or current_state_name == "Moving") and current_state_name != "Hit"

func can_block():
	var current_state_name = state_machine.get_current_state_name()
	return (current_state_name == "Idle" or current_state_name == "Moving") and current_state_name != "Hit"

func can_use_special():
	return special_meter >= character_data.special_meter_max and can_attack()

func can_use_ultimate():
	return ultimate_meter >= character_data.ultimate_meter_max and can_attack()

func is_blocking():
	return state_machine.get_current_state_name() == "Blocking"

# ===== MOVEMENT FUNCTIONS (delegate to movement component) =====

func move_left():
	movement_component.move_left()

func move_right():
	movement_component.move_right()

func stop_moving():
	movement_component.stop_moving()

func can_move():
	return movement_component.can_move()

func get_movement_animation() -> String:
	return movement_component.get_movement_animation()

func set_movement_direction(direction: float):
	movement_direction = direction

# ===== VISUAL FUNCTIONS (delegate to visual component) =====

func play_animation(animation_name: String):
	visual_component.play_animation(animation_name)

func do_simple_shake():
	visual_component.do_simple_shake()

# ===== COMBAT FUNCTIONS (delegate to combat component) =====

func apply_attack_hit():
	combat_component.apply_attack_hit()

func take_damage(damage_amount: int, ignore_block: bool) -> bool:
	return combat_component.take_damage(damage_amount, ignore_block)

func register_hit():
	combat_component.register_hit()

func charge_special_meter(amount: float):
	combat_component.charge_special_meter(amount)

func charge_ultimate_meter(amount: float):
	combat_component.charge_ultimate_meter(amount)

func is_opponent_in_attack_range(attack_range: float) -> bool:
	return combat_component.is_opponent_in_attack_range(attack_range)

func is_opponent_in_range():
	return is_opponent_in_attack_range(120.0)

# ===== ANIMATION HANDLING =====

func _on_animation_finished():
	var anim_name: String
	if sprite:
		anim_name = sprite.animation
	else:
		anim_name = ""
	
	# Forward to the current state if it's an attack state
	var state_name = state_machine.get_current_state_name()
	var active_state = state_machine.current_state
	
	if active_state.has_method("_on_animation_finished"):
		active_state._on_animation_finished(anim_name)
	else:
		# Fallback for states that don't handle animation finished
		match state_name:
			"LightAttack", "HeavyAttack", "SpecialAttack", "UltimateAttack":
				state_machine.change_state("Idle")
			"Hit":
				state_machine.change_state("Idle")

# ===== SOUND HANDLING =====

func play_sound(sound: AudioStream):
	if sound and audio_player:
		audio_player.stream = sound
		audio_player.play()

# ===== LEGACY COMPATIBILITY =====

# Keep handle_input as empty method for PlayerCharacter to override
func handle_input():
	pass
