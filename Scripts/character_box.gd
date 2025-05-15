extends Panel
class_name CharacterBox

var character_data: CharacterData

@onready var name_label = $InfoContainer/NameLabel
@onready var description_label = $InfoContainer/DescriptionLabel
@onready var background_color = $BackgroundColor
@onready var animation_player = $AnimationPlayer

var is_hovered = false
var is_selected = false

func _ready():
	# Ensure we have a consistent size from the start
	custom_minimum_size = Vector2(140, 140)
	size_flags_horizontal = SIZE_FILL
	size_flags_vertical = SIZE_FILL
	
	# Initial state setup
	if description_label:
		description_label.visible = false
	
	if animation_player and animation_player.has_animation("idle"):
		animation_player.play("idle")

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
	
	if background_color:
		background_color.color = data.color
	
	print("CharacterBox set up for: " + data.character_name)

func set_hovered(hovered: bool):
	is_hovered = hovered
	
	if hovered:
		z_index = 1  # Bring to front
		if description_label:
			description_label.visible = true  # Show description when hovered
	else:
		z_index = 0  # Normal depth
		if description_label and not is_selected:
			description_label.visible = false  # Hide description when not hovered
		
	if animation_player:
		if hovered and animation_player.has_animation("hover"):
			animation_player.play("hover")
		elif not hovered and not is_selected and animation_player.has_animation("idle"):
			animation_player.play("idle")

func set_selected(selected: bool):
	is_selected = selected
	
	if animation_player:
		if selected and animation_player.has_animation("select"):
			animation_player.play("select")
		elif not selected and not is_hovered and animation_player.has_animation("idle"):
			animation_player.play("idle")
		elif not selected and is_hovered and animation_player.has_animation("hover"):
			animation_player.play("hover")
