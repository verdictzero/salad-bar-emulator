extends CanvasLayer
class_name TouchControls

@export var joystick_size: float = 150.0
@export var button_size: float = 80.0
@export var opacity: float = 0.4

var left_joystick: Control
var jump_button: Control
var sprint_button: Control

var joystick_center: Vector2
var is_touching_joystick: bool = false
var joystick_input: Vector2 = Vector2.ZERO

signal movement_input(direction: Vector2)
signal jump_pressed()
signal sprint_pressed(pressed: bool)

func _ready():
	if not OS.has_feature("mobile"):
		visible = false
		return
	
	create_touch_controls()

func create_touch_controls():
	left_joystick = create_joystick()
	jump_button = create_button("JUMP", Vector2(get_viewport().size.x - 100, get_viewport().size.y - 100))
	sprint_button = create_button("RUN", Vector2(get_viewport().size.x - 200, get_viewport().size.y - 100))

func create_joystick() -> Control:
	var joystick = Control.new()
	joystick.size = Vector2(joystick_size, joystick_size)
	joystick.position = Vector2(50, get_viewport().size.y - joystick_size - 50)
	joystick_center = joystick.position + joystick.size * 0.5
	
	var bg = ColorRect.new()
	bg.size = joystick.size
	bg.color = Color(0.2, 0.2, 0.2, opacity)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	joystick.add_child(bg)
	
	var knob = ColorRect.new()
	knob.size = Vector2(50, 50)
	knob.color = Color(0.8, 0.8, 0.8, opacity * 1.5)
	knob.position = (joystick.size - knob.size) * 0.5
	knob.name = "Knob"
	joystick.add_child(knob)
	
	add_child(joystick)
	return joystick

func create_button(text: String, pos: Vector2) -> Control:
	var button = Control.new()
	button.size = Vector2(button_size, button_size)
	button.position = pos
	
	var bg = ColorRect.new()
	bg.size = button.size
	bg.color = Color(0.3, 0.3, 0.3, opacity)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(bg)
	
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", Color.WHITE)
	button.add_child(label)
	
	add_child(button)
	return button

func _input(event):
	if not OS.has_feature("mobile"):
		return
	
	if event is InputEventScreenTouch:
		handle_touch(event)
	elif event is InputEventScreenDrag:
		handle_drag(event)

func handle_touch(event: InputEventScreenTouch):
	var touch_pos = event.position
	
	if event.pressed:
		if is_in_joystick_area(touch_pos):
			is_touching_joystick = true
			update_joystick(touch_pos)
		elif is_in_button_area(jump_button, touch_pos):
			jump_pressed.emit()
			Input.action_press("jump")
		elif is_in_button_area(sprint_button, touch_pos):
			sprint_pressed.emit(true)
			Input.action_press("sprint")
	else:
		if is_touching_joystick:
			is_touching_joystick = false
			joystick_input = Vector2.ZERO
			reset_joystick()
			clear_movement_input()
		
		Input.action_release("jump")
		Input.action_release("sprint")
		sprint_pressed.emit(false)

func handle_drag(event: InputEventScreenDrag):
	if is_touching_joystick:
		update_joystick(event.position)

func is_in_joystick_area(pos: Vector2) -> bool:
	var rect = Rect2(left_joystick.position, left_joystick.size)
	return rect.has_point(pos)

func is_in_button_area(button: Control, pos: Vector2) -> bool:
	var rect = Rect2(button.position, button.size)
	return rect.has_point(pos)

func update_joystick(touch_pos: Vector2):
	var offset = touch_pos - joystick_center
	var distance = offset.length()
	var max_distance = joystick_size * 0.4
	
	if distance > max_distance:
		offset = offset.normalized() * max_distance
	
	joystick_input = offset / max_distance
	
	var knob = left_joystick.get_node("Knob")
	knob.position = (left_joystick.size - knob.size) * 0.5 + offset
	
	apply_movement_input()

func reset_joystick():
	var knob = left_joystick.get_node("Knob")
	knob.position = (left_joystick.size - knob.size) * 0.5

func apply_movement_input():
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_backward")
	
	if joystick_input.x < -0.3:
		Input.action_press("move_left")
	elif joystick_input.x > 0.3:
		Input.action_press("move_right")
	
	if joystick_input.y < -0.3:
		Input.action_press("move_forward")
	elif joystick_input.y > 0.3:
		Input.action_press("move_backward")

func clear_movement_input():
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_backward")