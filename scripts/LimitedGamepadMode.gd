extends Node
class_name LimitedGamepadMode

# Manages limited gamepad mode with only D-pad + A,B,X,Y,Start,Select buttons
# For retro controllers or simple mobile gamepads

signal mode_changed(enabled: bool)

@export var enabled: bool = false : set = set_enabled
@export var camera_rotation_speed: float = 90.0  # Degrees per second
@export var camera_step_angle: float = 45.0  # Degrees per tap

enum CameraMode {
	AUTO_FOLLOW,     # Camera auto-follows movement direction
	HOLD_MODIFIER,   # Hold X button + D-pad to control camera
	TAP_ROTATE       # Tap X/Y to rotate camera left/right
}

@export var camera_mode: CameraMode = CameraMode.TAP_ROTATE

var camera_rotation_input: Vector2 = Vector2.ZERO
var modifier_held: bool = false

func _ready():
	add_to_group("limited_gamepad_mode")
	set_process(enabled)

func set_enabled(value: bool):
	enabled = value
	set_process(enabled)
	mode_changed.emit(enabled)

	# Save preference
	var config = ConfigFile.new()
	config.load("user://game_settings.cfg")
	config.set_value("controls", "limited_gamepad_mode", enabled)
	config.set_value("controls", "camera_mode", camera_mode)
	config.save("user://game_settings.cfg")

func _process(delta):
	if not enabled:
		camera_rotation_input = Vector2.ZERO
		return

	match camera_mode:
		CameraMode.HOLD_MODIFIER:
			handle_hold_modifier_camera()
		CameraMode.TAP_ROTATE:
			handle_tap_rotate_camera()
		CameraMode.AUTO_FOLLOW:
			# Auto-follow is handled in the player controller
			pass

func handle_hold_modifier_camera():
	# X button acts as camera modifier
	modifier_held = Input.is_action_pressed("action_x")

	if modifier_held:
		# D-pad controls camera when X is held
		camera_rotation_input.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		camera_rotation_input.y = Input.get_action_strength("move_forward") - Input.get_action_strength("move_backward")
	else:
		camera_rotation_input = Vector2.ZERO

func handle_tap_rotate_camera():
	camera_rotation_input = Vector2.ZERO

	# L button or X button rotates camera left
	if Input.is_action_just_pressed("action_l") or Input.is_action_just_pressed("action_x"):
		camera_rotation_input.x = -1.0

	# R button or Y button rotates camera right
	if Input.is_action_just_pressed("action_r") or Input.is_action_just_pressed("action_y"):
		camera_rotation_input.x = 1.0

func get_camera_input() -> Vector2:
	return camera_rotation_input

func is_modifier_held() -> bool:
	return modifier_held and camera_mode == CameraMode.HOLD_MODIFIER

func should_block_movement() -> bool:
	# Block movement when using D-pad for camera control
	return camera_mode == CameraMode.HOLD_MODIFIER and modifier_held

func load_settings():
	var config = ConfigFile.new()
	if config.load("user://game_settings.cfg") == OK:
		enabled = config.get_value("controls", "limited_gamepad_mode", false)
		camera_mode = config.get_value("controls", "camera_mode", CameraMode.TAP_ROTATE)
