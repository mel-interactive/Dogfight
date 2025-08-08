# VictoryState.gd - Clean victory state with slide-in effect
extends State
class_name VictoryState

var victory_animation_started: bool = false

# Slide-in system
var slide_timer: float = 0.0
var slide_duration: float = 0.5
var sliding: bool = false
var start_position: Vector2
var target_position: Vector2

func enter():
	character.velocity = Vector2.ZERO
	start_victory_slide()

func start_victory_slide():
	start_position = character.global_position
	target_position = get_character_spawn_position(character.player_number)
	
	if start_position.distance_to(target_position) > 10.0:
		sliding = true
		slide_timer = 0.0
		character.visual_component.start_speed_lines()
	else:
		sliding = false
		start_victory_animation()

func get_character_spawn_position(player_num: int) -> Vector2:
	var fight_scene = character.get_tree().current_scene
	if fight_scene.has_node("Positions/Player" + str(player_num) + "Position"):
		return fight_scene.get_node("Positions/Player" + str(player_num) + "Position").global_position
	
	var viewport_size = character.get_viewport().get_visible_rect().size
	if player_num == 1:
		return Vector2(viewport_size.x * 0.25, character.global_position.y)
	else:
		return Vector2(viewport_size.x * 0.75, character.global_position.y)

func update(delta):
	if sliding:
		slide_timer += delta
		var slide_progress = slide_timer / slide_duration
		
		var eased_progress = 1.0 - pow(1.0 - slide_progress, 3.0)
		eased_progress = clamp(eased_progress, 0.0, 1.0)
		
		var movement_direction = (target_position - start_position).normalized()
		character.visual_component.update_speed_lines_direction(movement_direction)
		
		character.global_position = start_position.lerp(target_position, eased_progress)
		
		if slide_progress >= 1.0:
			sliding = false
			character.global_position = target_position
			character.visual_component.stop_speed_lines()
			start_victory_animation()

func start_victory_animation():
	victory_animation_started = true
	var animation_name = get_animation_name()
	character.play_animation(animation_name)
	
	if character.character_data and character.character_data.victory_sound:
		character.play_sound(character.character_data.victory_sound)

func get_animation_name() -> String:
	if character.character_data and character.character_data.has_base_animation("victory"):
		return "victory"
	elif character.character_data and character.character_data.has_base_animation("idle"):
		return "idle"
	elif character.character_data and character.character_data.has_base_animation("entrance"):
		return "entrance"
	else:
		return "idle"

func physics_update(_delta: float):
	if not sliding:
		character.velocity.x = 0

func exit():
	victory_animation_started = false
	sliding = false
	
	if character.visual_component:
		character.visual_component.stop_speed_lines()
