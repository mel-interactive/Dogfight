# HitState.gd
extends State
class_name HitState

var hit_timer: float = 0.0

func enter():
	print("Entering Hit state")
	hit_timer = 0.0
	character.velocity.x = 0
	character.movement_direction = 0.0
	
	if character.sprite and character.sprite.sprite_frames and character.sprite.sprite_frames.has_animation("hit"):
		character.play_animation("hit")

func update(delta):
	hit_timer += delta
	
	# Use a simple fixed duration for now - 0.3 seconds
	var hit_duration = 0.3
	
	# Try to get the actual duration from character data if available
	if character.character_data and "hit_stun_duration" in character.character_data:
		hit_duration = character.character_data.hit_stun_duration
	
	print("Hit timer: ", hit_timer, " / ", hit_duration)
	
	if hit_timer >= hit_duration:
		print("Hit state finished, transitioning to Idle")
		state_machine.change_state("Idle")

func physics_update(delta):
	# Force stop movement when being hit
	character.velocity.x = 0
	character.movement_direction = 0.0
