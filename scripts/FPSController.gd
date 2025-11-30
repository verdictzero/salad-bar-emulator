extends CharacterBody3D
class_name FPSController

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var sensitivity: float = 0.003
@export var gamepad_sensitivity: float = 3.0
@export var bob_freq: float = 2.0
@export var bob_amp: float = 0.08

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed: float
var mouse_captured: bool = false
var t_bob: float = 0.0
var total_distance: float = 0.0
var last_position: Vector3
var debug_timer: float = 0.0
var last_chunk_position: Vector2 = Vector2.INF
var limited_gamepad_mode: LimitedGamepadMode = null

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

func _ready():
	set_mouse_captured(true)
	last_position = position
	DebugLogger.log_player("FPS Controller initialized at position: %s" % str(global_position))

	# Find limited gamepad mode manager
	await get_tree().process_frame
	var limited_mode_nodes = get_tree().get_nodes_in_group("limited_gamepad_mode")
	if limited_mode_nodes.size() > 0:
		limited_gamepad_mode = limited_mode_nodes[0]

func _input(event):
	# Mouse camera control
	if event is InputEventMouseMotion and mouse_captured:
		rotate_y(-event.relative.x * sensitivity)
		camera_pivot.rotate_x(-event.relative.y * sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2, PI/2)

	# Toggle mouse capture
	if event.is_action_pressed("ui_cancel"):
		set_mouse_captured(!mouse_captured)

func _physics_process(delta):
	handle_gravity(delta)
	handle_jump()
	handle_gamepad_camera(delta)
	handle_movement(delta)
	handle_head_bob(delta)
	move_and_slide()
	update_distance()
	update_terrain_system()
	debug_position_tracking(delta)

func handle_gravity(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

func handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

func handle_gamepad_camera(delta):
	# Check if using limited gamepad mode
	if limited_gamepad_mode and limited_gamepad_mode.enabled:
		var camera_input = limited_gamepad_mode.get_camera_input()

		match limited_gamepad_mode.camera_mode:
			LimitedGamepadMode.CameraMode.TAP_ROTATE:
				# Instant rotation by step angle
				if abs(camera_input.x) > 0.1:
					rotate_y(-camera_input.x * deg_to_rad(limited_gamepad_mode.camera_step_angle))
			LimitedGamepadMode.CameraMode.HOLD_MODIFIER:
				# Smooth rotation while holding modifier
				if abs(camera_input.x) > 0.1 or abs(camera_input.y) > 0.1:
					rotate_y(-camera_input.x * deg_to_rad(limited_gamepad_mode.camera_rotation_speed) * delta)
					camera_pivot.rotate_x(-camera_input.y * deg_to_rad(limited_gamepad_mode.camera_rotation_speed) * delta)
					camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2, PI/2)
			LimitedGamepadMode.CameraMode.AUTO_FOLLOW:
				# Auto-rotate camera to follow movement direction
				var input_dir = get_movement_input()
				if input_dir.length() > 0.1:
					var target_rotation = atan2(input_dir.x, -input_dir.y)
					var current_rotation = rotation.y
					var angle_diff = angle_difference(current_rotation, target_rotation)

					# Smoothly rotate towards movement direction
					if abs(angle_diff) > 0.1:
						rotate_y(sign(angle_diff) * min(abs(angle_diff), deg_to_rad(limited_gamepad_mode.camera_rotation_speed) * delta))
	else:
		# Standard gamepad camera control with right stick
		var camera_x = Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left")
		var camera_y = Input.get_action_strength("camera_down") - Input.get_action_strength("camera_up")

		if abs(camera_x) > 0.1 or abs(camera_y) > 0.1:
			rotate_y(-camera_x * gamepad_sensitivity * delta)
			camera_pivot.rotate_x(-camera_y * gamepad_sensitivity * delta)
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2, PI/2)

func angle_difference(from: float, to: float) -> float:
	var diff = fmod(to - from, TAU)
	if diff > PI:
		diff -= TAU
	elif diff < -PI:
		diff += TAU
	return diff

func get_movement_input() -> Vector2:
	var input_dir = Vector2.ZERO

	# Don't process movement if limited mode is blocking (using D-pad for camera)
	if limited_gamepad_mode and limited_gamepad_mode.should_block_movement():
		return input_dir

	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if Input.is_action_pressed("move_forward"):
		input_dir.y += 1
	if Input.is_action_pressed("move_backward"):
		input_dir.y -= 1

	return input_dir

func handle_movement(delta):
	var input_dir = get_movement_input()

	if Input.is_action_pressed("sprint"):
		speed = sprint_speed
	else:
		speed = walk_speed

	var direction = (transform.basis * Vector3(input_dir.x, 0, -input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

func handle_head_bob(delta):
	t_bob += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = Vector3(
		cos(t_bob * bob_freq) * bob_amp,
		sin(t_bob * bob_freq * 2) * bob_amp,
		0
	)

func update_distance():
	var distance_moved = position.distance_to(last_position)
	total_distance += distance_moved
	last_position = position

func get_distance_travelled() -> float:
	return total_distance

func update_terrain_system():
	var terrain_system = get_tree().get_first_node_in_group("terrain_system")
	if terrain_system:
		terrain_system.set_player_position(global_position)
	else:
		DebugLogger.log_error("Terrain system not found in scene tree!")

func debug_position_tracking(delta):
	debug_timer += delta
	if debug_timer >= 1.0:  # Log every second
		var terrain_system = get_tree().get_first_node_in_group("terrain_system")
		if terrain_system:
			var current_chunk = terrain_system.world_to_chunk(global_position)
			var terrain_height = terrain_system.get_terrain_height_at_world_position(global_position)
			var height_diff = global_position.y - terrain_height
			
			DebugLogger.log_player("Pos: %s | Chunk: %s | TerrainHeight: %.2f | HeightDiff: %.2f | OnFloor: %s" % [
				str(global_position), str(current_chunk), terrain_height, height_diff, is_on_floor()
			])
			
			if current_chunk != last_chunk_position:
				DebugLogger.log_player("CHUNK CHANGED: %s -> %s" % [str(last_chunk_position), str(current_chunk)])
				last_chunk_position = current_chunk
			
			if height_diff < -5.0:
				DebugLogger.log_error("PLAYER FALLING THROUGH TERRAIN! Height diff: %.2f" % height_diff)
			
			if not is_on_floor() and velocity.y < -10.0:
				DebugLogger.log_warning("Player falling fast! Velocity Y: %.2f" % velocity.y)
		else:
			DebugLogger.log_error("Cannot access terrain system for position tracking")
		
		debug_timer = 0.0

func set_mouse_captured(captured: bool):
	mouse_captured = captured
	if captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
