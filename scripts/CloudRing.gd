extends Node3D
class_name CloudRing

@export_group("Ring Settings")
@export var ring_radius_min: float = 400.0  # Minimum distance from player
@export var ring_radius_max: float = 800.0  # Maximum distance from player
@export var cloud_count: int = 24  # Number of clouds in the ring
@export var rotation_speed: float = 0.5  # Degrees per second
@export var cloud_height_min: float = 50.0
@export var cloud_height_max: float = 120.0

@export_group("Cloud Appearance")
@export var cloud_scale_min: float = 200.0
@export var cloud_scale_max: float = 400.0
@export var cloud_opacity: float = 0.8
@export var fog_opacity: float = 0.8

@export_group("Tracking")
@export var follow_player: bool = true
@export var recenter_interval: float = 2.0  # How often to recenter on player

var cloud_sprites: Array[Texture2D] = []
var cloud_instances: Array[MeshInstance3D] = []
var cloud_shader: Shader
var ring_center: Vector3 = Vector3.ZERO
var target_ring_center: Vector3 = Vector3.ZERO
var recenter_timer: float = 0.0
var ring_rotation: float = 0.0
var center_lerp_speed: float = 2.0  # How fast to smoothly move toward player
var environment: Environment

func _ready():
	add_to_group("cloud_ring")
	load_cloud_textures()
	setup_material()
	find_environment()
	create_cloud_ring()

func load_cloud_textures():
	# Load all cloud textures (big and small clouds)
	var cloud_paths = [
		"res://big_cloud_1.png",
		"res://big_cloud_2.png",
		"res://small_cloud_1.png",
		"res://small_cloud_2.png"
	]

	for path in cloud_paths:
		if ResourceLoader.exists(path):
			var texture = load(path)
			if texture:
				cloud_sprites.append(texture)

	if cloud_sprites.is_empty():
		push_warning("CloudRing: No cloud textures found (expected big_cloud_*.png, small_cloud_*.png)")

func setup_material():
	cloud_shader = Shader.new()
	cloud_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, fog_disabled;

uniform sampler2D cloud_texture : source_color, filter_nearest;
uniform float opacity : hint_range(0.0, 1.0) = 0.8;
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
	vec4 tex = texture(cloud_texture, UV);

	// Custom fog based on distance
	float fog_factor = 1.0 - exp(-vertex_distance * 0.002);
	fog_factor = clamp(fog_factor * fog_opacity, 0.0, 1.0);

	ALBEDO = mix(tex.rgb, fog_color, fog_factor);
	ALPHA = tex.a * opacity;
}

"""

func create_cloud_ring():
	if cloud_sprites.is_empty():
		return

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345  # Fixed seed for consistent cloud placement

	for i in range(cloud_count):
		var cloud = create_cloud_instance(rng)

		# Position around the ring
		var angle = (float(i) / cloud_count) * TAU
		var height = rng.randf_range(cloud_height_min, cloud_height_max)
		var radius = rng.randf_range(ring_radius_min, ring_radius_max)

		# Store the base angle and radius in metadata for rotation
		cloud.set_meta("base_angle", angle)
		cloud.set_meta("height", height)
		cloud.set_meta("radius", radius)

		update_cloud_position(cloud)

		add_child(cloud)
		cloud_instances.append(cloud)

func create_cloud_instance(rng: RandomNumberGenerator) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var quad = QuadMesh.new()

	# Pick a random texture
	var texture = cloud_sprites[rng.randi() % cloud_sprites.size()]

	# Get texture aspect ratio to preserve it
	var tex_width = texture.get_width()
	var tex_height = texture.get_height()
	var aspect_ratio = float(tex_width) / float(tex_height) if tex_height > 0 else 1.0

	# Random size, preserving texture aspect ratio
	var scale_factor = rng.randf_range(cloud_scale_min, cloud_scale_max)
	quad.size = Vector2(scale_factor * aspect_ratio, scale_factor)

	mesh_instance.mesh = quad

	# Create unique shader material for this cloud
	var mat = ShaderMaterial.new()
	mat.shader = cloud_shader
	mat.set_shader_parameter("cloud_texture", texture)
	mat.set_shader_parameter("opacity", cloud_opacity)
	mat.set_shader_parameter("fog_opacity", fog_opacity)
	mesh_instance.material_override = mat

	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	return mesh_instance

func update_cloud_position(cloud: MeshInstance3D):
	var base_angle: float = cloud.get_meta("base_angle")
	var height: float = cloud.get_meta("height")
	var radius: float = cloud.get_meta("radius")

	var current_angle = base_angle + deg_to_rad(ring_rotation)

	var x = cos(current_angle) * radius
	var z = sin(current_angle) * radius

	cloud.global_position = ring_center + Vector3(x, height, z)

func _process(delta):
	# Rotate the ring slowly
	ring_rotation += rotation_speed * delta
	if ring_rotation >= 360.0:
		ring_rotation -= 360.0

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
		for cloud in cloud_instances:
			var mat = cloud.material_override as ShaderMaterial
			if mat:
				mat.set_shader_parameter("fog_color", fog_color)

	# Update all cloud positions
	for cloud in cloud_instances:
		update_cloud_position(cloud)

func find_environment():
	var world_env = get_tree().get_first_node_in_group("world_environment")
	if not world_env:
		world_env = get_parent().get_parent().find_child("WorldEnvironment")
	if world_env:
		environment = world_env.environment

func set_ring_center(center: Vector3):
	ring_center = Vector3(center.x, 0, center.z)
