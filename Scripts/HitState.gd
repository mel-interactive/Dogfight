# HitState.gd - FIXED to use VisualComponent
extends State
class_name HitState

var hit_timer: float = 0.0

func enter():
	hit_timer = 0.0
	character.velocity.x = 0
	character.movement_direction = 0.0
	
	# FIXED: Use visual_component
	if character.visual_component and character.visual_component.has_animation("hit"):
		character.play_animation("hit")

func update(delta):
	hit_timer += delta
	
	# Use a simple fixed duration for now - 0.3 seconds
	var hit_duration = 0.3
	
	# Try to get the actual duration from character data if available
	if character.character_data and "hit_stun_duration" in character.character_data:
		hit_duration = character.character_data.hit_stun_duration

	
	if hit_timer >= hit_duration:
		state_machine.change_state("Idle")

func physics_update(_delta):
	# Force stop movement when being hit
	character.velocity.x = 0
	character.movement_direction = 0.0
