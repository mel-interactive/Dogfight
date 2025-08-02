# StateMachine.gd
extends Node
class_name StateMachine

signal state_changed(old_state: String, new_state: String)

var current_state: State
var states: Dictionary = {}
var character: BaseCharacter

func _ready():
	character = get_parent()
	
	# Wait for all children to be added and ready
	await get_tree().process_frame
	
	# Register all State children
	for child in get_children():
		if child is State:
			register_state(child.name, child)
	
	print("StateMachine registered states: ", states.keys())

func register_state(state_name: String, state: State):
	states[state_name] = state
	state.state_machine = self
	state.character = character
	print("Registered state: ", state_name)

func start(initial_state_name: String):
	print("Starting state machine with initial state: ", initial_state_name)
	print("Available states: ", states.keys())
	change_state(initial_state_name)

func change_state(new_state_name: String) -> bool:
	if not states.has(new_state_name):
		push_error("State '" + new_state_name + "' not found! Available states: " + str(states.keys()))
		return false
	
	var old_state_name = ""
	if current_state:
		old_state_name = current_state.name
		current_state.exit()
	
	current_state = states[new_state_name]
	current_state.enter()
	
	emit_signal("state_changed", old_state_name, new_state_name)
	return true

func get_current_state_name() -> String:
	return current_state.name if current_state else ""

func _process(delta):
	if current_state:
		current_state.update(delta)

func _physics_process(delta):
	if current_state:
		current_state.physics_update(delta)
