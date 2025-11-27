extends Node

# Autoload script to manage input mappings globally

func _ready():
	# Load saved input mappings when the game starts
	load_input_mapping()

func load_input_mapping():
	var config = ConfigFile.new()
	var err = config.load("user://input_mapping.cfg")

	if err != OK:
		# No saved config, use defaults
		return

	# Define the actions we support remapping
	var rebindable_actions = [
		"move_forward",
		"move_backward",
		"move_left",
		"move_right",
		"jump",
		"sprint",
		"camera_up",
		"camera_down",
		"camera_left",
		"camera_right"
	]

	for action in rebindable_actions:
		if config.has_section_key("input", action):
			var keycode = config.get_value("input", action)

			# Clear existing events
			InputMap.action_erase_events(action)

			# Add the new mapped key
			var event = InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)

func save_input_mapping():
	var config = ConfigFile.new()

	var rebindable_actions = [
		"move_forward",
		"move_backward",
		"move_left",
		"move_right",
		"jump",
		"sprint",
		"camera_up",
		"camera_down",
		"camera_left",
		"camera_right"
	]

	for action in rebindable_actions:
		var events = InputMap.action_get_events(action)
		if events.size() > 0:
			var event = events[0]
			if event is InputEventKey:
				config.set_value("input", action, event.physical_keycode)

	config.save("user://input_mapping.cfg")
