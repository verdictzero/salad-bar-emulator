extends Control
class_name ControlsMenu

signal back_to_main

@onready var bindings_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/BindingsContainer
@onready var back_button: Button = $PanelContainer/MarginContainer/VBoxContainer/BackButton
@onready var reset_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ResetButton
@onready var listening_label: Label = $ListeningLabel

var is_listening: bool = false
var current_action: String = ""
var action_buttons: Dictionary = {}

# Define the actions we want to allow rebinding
var rebindable_actions = {
	"move_forward": "Move Forward",
	"move_backward": "Move Backward",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"jump": "Jump",
	"sprint": "Sprint",
	"camera_up": "Camera Up",
	"camera_down": "Camera Down",
	"camera_left": "Camera Left",
	"camera_right": "Camera Right"
}

var first_button: Button = null

func _ready():
	back_button.pressed.connect(_on_back_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	listening_label.hide()

	# Load saved input mappings
	load_input_mapping()

	# Create UI for each action
	create_bindings_ui()

	# Connect visibility changed signal for gamepad focus
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	if visible and first_button:
		# Focus first button when menu becomes visible for gamepad navigation
		await get_tree().process_frame
		first_button.grab_focus()

func create_bindings_ui():
	# Clear existing children
	for child in bindings_container.get_children():
		child.queue_free()

	action_buttons.clear()
	first_button = null
	var last_button: Button = null

	# Create a row for each action
	for action in rebindable_actions:
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size.y = 40

		# Action label
		var label = Label.new()
		label.text = rebindable_actions[action] + ":"
		label.custom_minimum_size.x = 200
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hbox.add_child(label)

		# Current key button
		var key_button = Button.new()
		key_button.custom_minimum_size.x = 150
		update_button_text(key_button, action)
		key_button.pressed.connect(_on_key_button_pressed.bind(action, key_button))
		hbox.add_child(key_button)

		# Setup gamepad navigation
		if last_button:
			last_button.focus_neighbor_bottom = last_button.get_path_to(key_button)
			key_button.focus_neighbor_top = key_button.get_path_to(last_button)
		else:
			first_button = key_button

		last_button = key_button
		action_buttons[action] = key_button
		bindings_container.add_child(hbox)

	# Connect last button to reset button
	if last_button:
		last_button.focus_neighbor_bottom = last_button.get_path_to(reset_button)
		reset_button.focus_neighbor_top = reset_button.get_path_to(last_button)

	# Connect reset to back
	reset_button.focus_neighbor_bottom = reset_button.get_path_to(back_button)
	back_button.focus_neighbor_top = back_button.get_path_to(reset_button)

	# Connect back to first button
	if first_button:
		back_button.focus_neighbor_bottom = back_button.get_path_to(first_button)
		first_button.focus_neighbor_top = first_button.get_path_to(back_button)

func update_button_text(button: Button, action: String):
	var events = InputMap.action_get_events(action)
	if events.size() > 0:
		# Find first keyboard or joypad button event (skip motion events for display)
		for event in events:
			if event is InputEventKey:
				button.text = OS.get_keycode_string(event.physical_keycode)
				return
			elif event is InputEventJoypadButton:
				button.text = get_joypad_button_name(event.button_index)
				return

		# If only motion events, show the first one
		var event = events[0]
		if event is InputEventJoypadMotion:
			button.text = get_joypad_axis_name(event.axis, event.axis_value)
		else:
			button.text = "Unknown"
	else:
		button.text = "None"

func get_joypad_button_name(button_index: int) -> String:
	match button_index:
		JOY_BUTTON_A: return "A Button"
		JOY_BUTTON_B: return "B Button"
		JOY_BUTTON_X: return "X Button"
		JOY_BUTTON_Y: return "Y Button"
		JOY_BUTTON_BACK: return "Back"
		JOY_BUTTON_START: return "Start"
		JOY_BUTTON_LEFT_STICK: return "L-Stick"
		JOY_BUTTON_RIGHT_STICK: return "R-Stick"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_DPAD_UP: return "D-Up"
		JOY_BUTTON_DPAD_DOWN: return "D-Down"
		JOY_BUTTON_DPAD_LEFT: return "D-Left"
		JOY_BUTTON_DPAD_RIGHT: return "D-Right"
		_: return "Button %d" % button_index

func get_joypad_axis_name(axis: int, value: float) -> String:
	var direction = "+" if value > 0 else "-"
	match axis:
		JOY_AXIS_LEFT_X: return "L-Stick X%s" % direction
		JOY_AXIS_LEFT_Y: return "L-Stick Y%s" % direction
		JOY_AXIS_RIGHT_X: return "R-Stick X%s" % direction
		JOY_AXIS_RIGHT_Y: return "R-Stick Y%s" % direction
		JOY_AXIS_TRIGGER_LEFT: return "LT"
		JOY_AXIS_TRIGGER_RIGHT: return "RT"
		_: return "Axis %d%s" % [axis, direction]

func _on_key_button_pressed(action: String, button: Button):
	if is_listening:
		return

	is_listening = true
	current_action = action
	listening_label.text = "Press any key for: " + rebindable_actions[action]
	listening_label.show()
	button.text = "..."

func _input(event: InputEvent):
	if not is_listening:
		return

	# Handle keyboard input
	if event is InputEventKey and event.pressed:
		# Don't allow escape key to be bound
		if event.keycode == KEY_ESCAPE:
			cancel_listening()
			return

		# Remove old bindings
		InputMap.action_erase_events(current_action)

		# Add new binding
		InputMap.action_add_event(current_action, event)

		# Update button text
		if current_action in action_buttons:
			update_button_text(action_buttons[current_action], current_action)

		# Save to settings
		save_input_mapping()

		cancel_listening()

	# Handle gamepad button input
	elif event is InputEventJoypadButton and event.pressed:
		# Remove old bindings
		InputMap.action_erase_events(current_action)

		# Add new binding
		InputMap.action_add_event(current_action, event)

		# Update button text
		if current_action in action_buttons:
			update_button_text(action_buttons[current_action], current_action)

		# Save to settings
		save_input_mapping()

		cancel_listening()

	# Handle gamepad axis input (for analog sticks)
	elif event is InputEventJoypadMotion:
		# Only bind if the axis is moved significantly
		if abs(event.axis_value) > 0.5:
			# Remove old bindings
			InputMap.action_erase_events(current_action)

			# Add new binding
			InputMap.action_add_event(current_action, event)

			# Update button text
			if current_action in action_buttons:
				update_button_text(action_buttons[current_action], current_action)

			# Save to settings
			save_input_mapping()

			cancel_listening()

func cancel_listening():
	is_listening = false
	listening_label.hide()

	# Restore button text
	if current_action in action_buttons:
		update_button_text(action_buttons[current_action], current_action)

	current_action = ""

func _on_reset_pressed():
	# Reset all actions to defaults
	reset_to_defaults()

	# Update all button texts
	for action in action_buttons:
		update_button_text(action_buttons[action], action)

	# Save the reset settings
	save_input_mapping()

func reset_to_defaults():
	# Define default key and gamepad mappings
	var keyboard_defaults = {
		"move_forward": KEY_W,
		"move_backward": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE,
		"sprint": KEY_SHIFT
	}

	var gamepad_button_defaults = {
		"move_forward": JOY_BUTTON_DPAD_UP,
		"move_backward": JOY_BUTTON_DPAD_DOWN,
		"move_left": JOY_BUTTON_DPAD_LEFT,
		"move_right": JOY_BUTTON_DPAD_RIGHT,
		"jump": JOY_BUTTON_A,
		"sprint": JOY_BUTTON_B
	}

	var gamepad_axis_defaults = {
		"move_forward": {"axis": JOY_AXIS_LEFT_Y, "value": -1.0},
		"move_backward": {"axis": JOY_AXIS_LEFT_Y, "value": 1.0},
		"move_left": {"axis": JOY_AXIS_LEFT_X, "value": -1.0},
		"move_right": {"axis": JOY_AXIS_LEFT_X, "value": 1.0},
		"camera_up": {"axis": JOY_AXIS_RIGHT_Y, "value": -1.0},
		"camera_down": {"axis": JOY_AXIS_RIGHT_Y, "value": 1.0},
		"camera_left": {"axis": JOY_AXIS_RIGHT_X, "value": -1.0},
		"camera_right": {"axis": JOY_AXIS_RIGHT_X, "value": 1.0}
	}

	for action in rebindable_actions.keys():
		InputMap.action_erase_events(action)

		# Add keyboard binding if exists
		if action in keyboard_defaults:
			var key_event = InputEventKey.new()
			key_event.physical_keycode = keyboard_defaults[action]
			InputMap.action_add_event(action, key_event)

		# Add gamepad button binding if exists
		if action in gamepad_button_defaults:
			var button_event = InputEventJoypadButton.new()
			button_event.button_index = gamepad_button_defaults[action]
			InputMap.action_add_event(action, button_event)

		# Add gamepad axis binding if exists
		if action in gamepad_axis_defaults:
			var axis_event = InputEventJoypadMotion.new()
			axis_event.axis = gamepad_axis_defaults[action].axis
			axis_event.axis_value = gamepad_axis_defaults[action].value
			InputMap.action_add_event(action, axis_event)

func save_input_mapping():
	var config = ConfigFile.new()

	for action in rebindable_actions:
		var events = InputMap.action_get_events(action)
		if events.size() > 0:
			var event = events[0]
			if event is InputEventKey:
				config.set_value("input", action, event.physical_keycode)

	config.save("user://input_mapping.cfg")

func load_input_mapping():
	var config = ConfigFile.new()
	var err = config.load("user://input_mapping.cfg")

	if err != OK:
		return

	for action in rebindable_actions:
		if config.has_section_key("input", action):
			var keycode = config.get_value("input", action)

			InputMap.action_erase_events(action)

			var event = InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)

func _on_back_pressed():
	back_to_main.emit()
