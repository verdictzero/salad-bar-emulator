extends Node3D
class_name MountainRing

@export_group("Ring Settings")
@export var ring_radius: float = 350.0  # Fixed distance from player (in front of clouds)
@export var mountain_count: int = 16  # Number of mountains in the ring

@export_group("Mountain Appearance")
@export var mountain_scale_min: float = 54.4
@export var mountain_scale_max: float = 108.75
@export var mountain_height_offset: float = -20.0  # Offset from ground level
@export var fog_opacity: float = 0.95

@export_group("Tracking")
@export var follow_player: bool = true
@export var recenter_interval: float = 2.0  # How often to recenter on player

var mountain_sprites: Array[Texture2D] = []
var mountain_instances: Array[MeshInstance3D] = []
var mountain_shader: Shader
var ring_center: Vector3 = Vector3.ZERO
var target_ring_center: Vector3 = Vector3.ZERO
var recenter_timer: float = 0.0
var center_lerp_speed: float = 2.0
var environment: Environment

func _ready():
	add_to_group("mountain_ring")
	load_mountain_textures()
	setup_material()
	find_environment()
	create_mountain_ring()

func load_mountain_textures():
	# Load all mountain textures (mountain_1.png, mountain_2.png, etc.)
	var i = 1
	while true:
		var path = "res://mountain_%d.png" % i
		if ResourceLoader.exists(path):
			var texture = load(path)
			if texture:
				mountain_sprites.append(texture)
			i += 1
		else:
			break

	if mountain_sprites.is_empty():
		push_warning("MountainRing: No mountain textures found (expected mountain_1.png, mountain_2.png, etc.)")

func setup_material():
	mountain_shader = Shader.new()
	mountain_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, fog_disabled;

uniform sampler2D mountain_texture : source_color, filter_nearest;
uniform float fog_opacity : hint_range(0.0, 1.0) = 0.8;
uniform vec3 fog_color : source_color = vec3(0.85, 0.9, 1.0);

varying float vertex_distance;

void vertex() {
	// Billboard on Y axis only (fixed Y billboard)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);

	// Calculate distance from camera for custom fog
	vec4 world_pos = MODEL_MATRIX * vec4(VERTEX, 1.0);
	vertex_distance = length(world_pos.xyz - CAMERA_POSITION_WORLD);
}

void fragment() {
	vec4 tex = texture(mountain_texture, UV);

	// Custom fog based on distance
	float fog_factor = 1.0 - exp(-vertex_distance * 0.002);
	fog_factor = clamp(fog_factor * fog_opacity, 0.0, 1.0);

	ALBEDO = mix(tex.rgb, fog_color, fog_factor);
	ALPHA = tex.a;
}

"""

func create_mountain_ring():
	if mountain_sprites.is_empty():
		return

	var rng = RandomNumberGenerator.new()
	rng.seed = 54321  # Fixed seed for consistent mountain placement

	for i in range(mountain_count):
		var mountain = create_mountain_instance(rng)

		# Position evenly around the ring with slight variation
		var base_angle = (float(i) / mountain_count) * TAU
		var angle_offset = rng.randf_range(-0.1, 0.1)  # Slight angle variation

		# Store metadata
		mountain.set_meta("base_angle", base_angle + angle_offset)

		update_mountain_position(mountain)

		add_child(mountain)
		mountain_instances.append(mountain)

func create_mountain_instance(rng: RandomNumberGenerator) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var quad = QuadMesh.new()

	# Pick a random texture
	var texture = mountain_sprites[rng.randi() % mountain_sprites.size()]

	# Get texture aspect ratio to preserve it
	var tex_width = texture.get_width()
	var tex_height = texture.get_height()
	var aspect_ratio = float(tex_width) / float(tex_height) if tex_height > 0 else 1.0

	# Random size, preserving texture aspect ratio
	var scale_factor = rng.randf_range(mountain_scale_min, mountain_scale_max)
	quad.size = Vector2(scale_factor * aspect_ratio, scale_factor)

	mesh_instance.mesh = quad

	# Create shader material
	var mat = ShaderMaterial.new()
	mat.shader = mountain_shader
	mat.set_shader_parameter("mountain_texture", texture)
	mat.set_shader_parameter("fog_opacity", fog_opacity)
	mesh_instance.material_override = mat

	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	return mesh_instance

func update_mountain_position(mountain: MeshInstance3D):
	var base_angle: float = mountain.get_meta("base_angle")

	var x = cos(base_angle) * ring_radius
	var z = sin(base_angle) * ring_radius

	# Get the scale to calculate height offset (bottom of sprite at ground level)
	var quad = mountain.mesh as QuadMesh
	var height = quad.size.y * 0.5 + mountain_height_offset

	mountain.global_position = ring_center + Vector3(x, height, z)

func _process(delta):
	# Update target position periodically
	if follow_player:
		recenter_timer += delta
		if recenter_timer >= recenter_interval:
			recenter_timer = 0.0
			var player = get_tree().get_first_node_in_group("player")
			if player:
				target_ring_center = Vector3(player.global_position.x, 0, player.global_position.z)

	# Smoothly lerp ring center toward target
	ring_center = ring_center.lerp(target_ring_center, center_lerp_speed * delta)

	# Sync fog color with environment
	if environment:
		var fog_color = environment.fog_light_color
		for mountain in mountain_instances:
			var mat = mountain.material_override as ShaderMaterial
			if mat:
				mat.set_shader_parameter("fog_color", fog_color)

	# Update all mountain positions
	for mountain in mountain_instances:
		update_mountain_position(mountain)

func find_environment():
	var world_env = get_tree().get_first_node_in_group("world_environment")
	if not world_env:
		world_env = get_parent().get_parent().find_child("WorldEnvironment")
	if world_env:
		environment = world_env.environment

func set_ring_center(center: Vector3):
	ring_center = Vector3(center.x, 0, center.z)
