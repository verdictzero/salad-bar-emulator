extends Node3D
class_name MistRing

@export_group("Ring Settings")
@export var ring_radius_min: float = 120.0
@export var ring_radius_max: float = 280.0
@export var particle_count: int = 350
@export var particle_height_min: float = -10.0
@export var particle_height_max: float = 30.0

@export_group("Particle Appearance")
@export var particle_scale_min: float = 40.0
@export var particle_scale_max: float = 100.0
@export var particle_opacity: float = 0.7
@export var drift_speed: float = 1.5  # How fast particles drift around

@export_group("Tracking")
@export var follow_player: bool = true
@export var recenter_interval: float = 2.0

var particle_instances: Array[MeshInstance3D] = []
var mist_shader: Shader
var ring_center: Vector3 = Vector3.ZERO
var target_ring_center: Vector3 = Vector3.ZERO
var recenter_timer: float = 0.0
var center_lerp_speed: float = 2.0
var time_offset: float = 0.0

func _ready():
	add_to_group("mist_ring")
	setup_material()
	create_mist_ring()

func setup_material():
	mist_shader = Shader.new()
	mist_shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float opacity : hint_range(0.0, 1.0) = 0.5;
uniform vec3 base_color : source_color = vec3(0.25, 0.25, 0.25);

void vertex() {
	// Full billboard (face camera)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	// Create circular gradient (center to transparent edge)
	vec2 center_uv = UV - vec2(0.5);
	float dist = length(center_uv) * 2.0;
	float gradient = 1.0 - smoothstep(0.0, 1.0, dist);
	gradient = pow(gradient, 1.5);  // Softer falloff

	ALBEDO = base_color;
	ALPHA = gradient * opacity;
}
"""

func create_mist_ring():
	var rng = RandomNumberGenerator.new()
	rng.seed = 98765

	for i in range(particle_count):
		var mesh_instance = create_particle_instance(rng)

		var angle = rng.randf_range(0, TAU)
		var radius = rng.randf_range(ring_radius_min, ring_radius_max)
		var height = rng.randf_range(particle_height_min, particle_height_max)
		var drift_offset = rng.randf_range(0, TAU)  # Random phase for drifting

		mesh_instance.set_meta("base_angle", angle)
		mesh_instance.set_meta("radius", radius)
		mesh_instance.set_meta("height", height)
		mesh_instance.set_meta("drift_offset", drift_offset)
		mesh_instance.set_meta("drift_radius", rng.randf_range(5.0, 15.0))
		mesh_instance.set_meta("drift_speed", rng.randf_range(0.5, 1.5))

		update_particle_position(mesh_instance, 0.0)

		add_child(mesh_instance)
		particle_instances.append(mesh_instance)

func create_particle_instance(rng: RandomNumberGenerator) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var quad = QuadMesh.new()

	var scale_factor = rng.randf_range(particle_scale_min, particle_scale_max)
	quad.size = Vector2(scale_factor, scale_factor)

	mesh_instance.mesh = quad

	var mat = ShaderMaterial.new()
	mat.shader = mist_shader
	mat.set_shader_parameter("opacity", particle_opacity)
	mesh_instance.material_override = mat

	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	return mesh_instance

func update_particle_position(particle: MeshInstance3D, time: float):
	var base_angle: float = particle.get_meta("base_angle")
	var radius: float = particle.get_meta("radius")
	var height: float = particle.get_meta("height")
	var drift_offset: float = particle.get_meta("drift_offset")
	var drift_radius: float = particle.get_meta("drift_radius")
	var particle_drift_speed: float = particle.get_meta("drift_speed")

	# Add gentle drifting motion
	var drift_time = time * drift_speed * particle_drift_speed
	var drift_x = sin(drift_time + drift_offset) * drift_radius
	var drift_z = cos(drift_time * 0.7 + drift_offset) * drift_radius
	var drift_y = sin(drift_time * 0.5 + drift_offset) * drift_radius * 0.3

	var x = cos(base_angle) * radius + drift_x
	var z = sin(base_angle) * radius + drift_z
	var y = height + drift_y

	particle.global_position = ring_center + Vector3(x, y, z)

func _process(delta):
	time_offset += delta

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

	# Update all particle positions with drift
	for particle in particle_instances:
		update_particle_position(particle, time_offset)

func set_ring_center(center: Vector3):
	ring_center = Vector3(center.x, 0, center.z)
