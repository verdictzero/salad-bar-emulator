extends CharacterBody3D
class_name FPSController

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var sensitivity: float = 0.003
@export var bob_freq: float = 2.0
@export var bob_amp: float = 0.08

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed: float
var mouse_captured: bool = false
var t_bob: float = 0.0
var total_distance: float = 0.0
var last_position: Vector3

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

func _ready():
	set_mouse_captured(true)
	last_position = position

func _input(event):
	if event is InputEventMouseMotion and mouse_captured:
		rotate_y(-event.relative.x * sensitivity)
		camera_pivot.rotate_x(-event.relative.y * sensitivity)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, -PI/2, PI/2)
	
	if event.is_action_pressed("ui_cancel"):
		set_mouse_captured(!mouse_captured)

func _physics_process(delta):
	handle_gravity(delta)
	handle_jump()
	handle_movement(delta)
	handle_head_bob(delta)
	move_and_slide()
	update_distance()

func handle_gravity(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

func handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

func handle_movement(delta):
	var input_dir = Vector2.ZERO
	
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	if Input.is_action_pressed("move_forward"):
		input_dir.y += 1
	if Input.is_action_pressed("move_backward"):
		input_dir.y -= 1
	
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

func set_mouse_captured(captured: bool):
	mouse_captured = captured
	if captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE