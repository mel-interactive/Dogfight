# TitleScreen.gd
extends Node2D
class_name TitleScreen

@onready var pvp_button = $"pvpbuttoncombined/PVP Button"
@onready var pve_button = $"pvebuttoncombined/PVE Button"
@onready var pve_button_combined = $pvebuttoncombined
@onready var pvp_button_combined = $pvpbuttoncombined

# Controller navigation variables
var current_button_index := 0
var buttons := []
var original_scales := {}

# Background character animation system
var available_characters: Array = []
var background_characters: Array[AnimatedSprite2D] = []
var spawn_timer: float = 0.0
var spawn_interval: float = 5.0  # Spawn a character every 3 seconds

func _ready():
	# Make sure the GameStateManager is available globally
	if not get_node_or_null("/root/GameState_Manager"):
		var game_state_manager = load("res://Scripts/GameStateManager.gd").new()
		game_state_manager.name = "GameState_Manager"
		get_tree().root.add_child(game_state_manager)
	
	# Connect button signals
	pvp_button.pressed.connect(_on_pvp_pressed)
	pve_button.pressed.connect(_on_pve_pressed)
	
	# Setup controller navigation
	setup_controller_navigation()
	
	# Load available characters for background animations
	load_characters_for_background()
	
	# Start spawning background characters
	spawn_background_character()

func setup_controller_navigation():
	# Add combined nodes to navigation array for scaling
	buttons = [pvp_button_combined, pve_button_combined]
	
	# Store original scales for hover effect
	for button in buttons:
		original_scales[button] = button.scale
	
	# Set initial selection to first button (PVP)
	current_button_index = 0
	update_button_selection()

func _input(event):
	# Handle controller navigation using existing inputs + dpad up/down
	if Input.is_action_just_pressed("dpad_down") or Input.is_action_just_pressed("p1_heavy") or Input.is_action_just_pressed("p2_heavy"):
		navigate_down()
	elif Input.is_action_just_pressed("dpad_up") or Input.is_action_just_pressed("p1_light") or Input.is_action_just_pressed("p2_light"):
		navigate_up()
	elif Input.is_action_just_pressed("p1_ultimate") or Input.is_action_just_pressed("p2_ultimate"):
		press_current_button()

func navigate_down():
	if current_button_index < buttons.size() - 1:
		current_button_index += 1
		update_button_selection()

func navigate_up():
	if current_button_index > 0:
		current_button_index -= 1
		update_button_selection()

func press_current_button():
	# Press the actual button based on which combined node is selected
	if current_button_index == 0:
		pvp_button.emit_signal("pressed")
	elif current_button_index == 1:
		pve_button.emit_signal("pressed")

func update_button_selection():
	# Reset all buttons to normal scale and color
	for i in range(buttons.size()):
		var combined_node = buttons[i]
		var original_scale = original_scales[combined_node]
		
		if i == current_button_index:
			# Scale up selected combined nodeas
			combined_node.scale = original_scale * 1.01
			

			if i == 1:
				pvp_button.modulate = Color.WEB_GRAY 
			elif i == 0:
				pve_button.modulate = Color.WEB_GRAY
		else:
			combined_node.scale = original_scale
			
			if i == 1:
				pvp_button.modulate = Color.WHITE
			elif i == 0:
				pve_button.modulate = Color.WHITE

func _process(delta):
	spawn_timer += delta
	
	# Spawn new background characters periodically
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		spawn_background_character()
	
	# Clean up characters that have walked off screen
	cleanup_offscreen_characters()

func load_characters_for_background():
	var manager = get_node_or_null("/root/Character_Manager")
	if manager and manager.available_characters.size() > 0:
		available_characters = manager.available_characters.duplicate()
		print("Loaded ", available_characters.size(), " characters for background")
	else:
		print("No characters available for background animations")

func spawn_background_character():
	if available_characters.size() == 0:
		return
	
	# Pick a random character
	var random_character = available_characters[randi() % available_characters.size()]
	
	# Create animated sprite
	var character_sprite = AnimatedSprite2D.new()
	character_sprite.z_index = -10  # Behind UI elements
	add_child(character_sprite)
	
	# Setup character animation
	if setup_character_sprite(character_sprite, random_character):
		# Random direction (true = left to right, false = right to left)
		var direction_left_to_right = randf() < 0.5
		
		# Position character off-screen
		var viewport_size = get_viewport().get_visible_rect().size
		var start_y = randf_range(viewport_size.y * 0.4, viewport_size.y * 0.8)  # Random Y between 40% and 80% of screen
		
		if direction_left_to_right:
			character_sprite.global_position = Vector2(-100, start_y)  # Start off left side
			character_sprite.flip_h = true   # Flip to face right (walking left to right)
		else:
			character_sprite.global_position = Vector2(viewport_size.x + 100, start_y)  # Start off right side
			character_sprite.flip_h = false  # Normal orientation facing left (walking right to left)
		
		# Random scale for variety
		var random_scale = randf_range(2, 3)
		character_sprite.scale = Vector2(random_scale, random_scale)
		
		# Start walking animation
		character_sprite.play("run_forward")
		
		# Animate across screen
		animate_character_across_screen(character_sprite, direction_left_to_right)
		
		# Add to tracking array
		background_characters.append(character_sprite)
		
		print("Spawned background character: ", random_character.character_name)

func setup_character_sprite(sprite: AnimatedSprite2D, character_data: CharacterData) -> bool:
	sprite.sprite_frames = SpriteFrames.new()
	
	# Try to add the run_forward animation
	if character_data.has_base_animation("run_forward"):
		var run_anim = character_data.get_base_animation("run_forward")
		add_animation_to_sprite(sprite, "run_forward", run_anim)
		return true
	elif character_data.has_base_animation("idle"):
		# Fallback to idle if no run animation
		var idle_anim = character_data.get_base_animation("idle")
		add_animation_to_sprite(sprite, "run_forward", idle_anim)
		return true
	
	return false

func add_animation_to_sprite(sprite: AnimatedSprite2D, anim_name: String, frames: SpriteFrames):
	if not frames:
		return
	
	var source_animations = frames.get_animation_names()
	if source_animations.size() == 0:
		return
	
	var source_anim_name = source_animations[0]
	if frames.get_frame_count(source_anim_name) == 0:
		return
	
	# Create the animation
	sprite.sprite_frames.add_animation(anim_name)
	
	# Copy frames
	for i in range(frames.get_frame_count(source_anim_name)):
		var frame_texture = frames.get_frame_texture(source_anim_name, i)
		if frame_texture:
			sprite.sprite_frames.add_frame(anim_name, frame_texture)
	
	# Set animation properties
	if sprite.sprite_frames.get_frame_count(anim_name) > 0:
		sprite.sprite_frames.set_animation_speed(anim_name, frames.get_animation_speed(source_anim_name))
		sprite.sprite_frames.set_animation_loop(anim_name, true)  # Loop for continuous walking

func animate_character_across_screen(sprite: AnimatedSprite2D, left_to_right: bool):
	var viewport_size = get_viewport().get_visible_rect().size
	var walk_speed = randf_range(80, 150)  # Random walking speed
	var duration = viewport_size.x / walk_speed
	
	var tween = create_tween()
	
	if left_to_right:
		# Walk from left to right
		tween.tween_property(sprite, "global_position:x", viewport_size.x + 100, duration)
	else:
		# Walk from right to left
		tween.tween_property(sprite, "global_position:x", -100, duration)
	
	# Remove sprite when tween completes
	tween.tween_callback(func(): 
		if is_instance_valid(sprite):
			background_characters.erase(sprite)
			sprite.queue_free()
	)

func cleanup_offscreen_characters():
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Remove characters that are way off screen (safety cleanup)
	for i in range(background_characters.size() - 1, -1, -1):
		var character = background_characters[i]
		if not is_instance_valid(character):
			background_characters.remove_at(i)
			continue
		
		var pos_x = character.global_position.x
		if pos_x < -200 or pos_x > viewport_size.x + 200:
			background_characters.remove_at(i)
			character.queue_free()

func _on_pvp_pressed():
	print("PVP Mode selected")
	# Set game mode to PVP
	var gsm = get_node_or_null("/root/GameState_Manager")
	if gsm:
		gsm.game_mode = "PVP"
	
	# Go to character select
	get_tree().change_scene_to_file("res://Scenes/character_select_screen.tscn")

func _on_pve_pressed():
	print("PVE Mode selected")
	# Set game mode to PVE
	var gsm = get_node_or_null("/root/GameState_Manager")
	if gsm:
		gsm.game_mode = "PVE"
	
	# Go to character select (same screen, but will behave differently)
	get_tree().change_scene_to_file("res://Scenes/character_select_screen.tscn")
