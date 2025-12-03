extends Node3D
class_name DayNightCycle

@export_group("Cycle Settings")
@export var day_length_seconds: float = 120.0  # Full day/night cycle duration
@export var time_of_day: float = 0.25  # 0.0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset

@export_group("Sun/Moon Settings")
@export var orbit_radius: float = 200.0
@export var sun_size: float = 15.0
@export var moon_size: float = 8.0
@export var recenter_interval: float = 2.0  # Recenter sun/moon on player every N seconds

@export_group("Ambient Light")
@export var day_ambient_color: Color = Color(0.95, 0.95, 1.0)
@export var day_ambient_energy: float = 0.4
@export var night_ambient_color: Color = Color(0.1, 0.1, 0.2)
@export var night_ambient_energy: float = 0.05
@export var golden_hour_ambient_color: Color = Color(1.0, 0.8, 0.5)
@export var golden_hour_ambient_energy: float = 0.35

@export_group("Fog Settings")
@export var day_fog_color: Color = Color(0.85, 0.9, 1.0)
@export var night_fog_color: Color = Color(0.05, 0.05, 0.12)
@export var sunrise_fog_color: Color = Color(1.0, 0.6, 0.35)
@export var sunset_fog_color: Color = Color(1.0, 0.45, 0.2)

@export_group("Sky Colors")
@export var day_sky_top: Color = Color(0.35, 0.55, 0.95)
@export var day_sky_bottom: Color = Color(0.6, 0.8, 1.0)
@export var night_sky_top: Color = Color(0.02, 0.02, 0.08)
@export var night_sky_bottom: Color = Color(0.08, 0.06, 0.15)
@export var sunrise_sky_top: Color = Color(0.5, 0.4, 0.7)
@export var sunrise_sky_bottom: Color = Color(1.0, 0.55, 0.25)
@export var sunset_sky_top: Color = Color(0.4, 0.25, 0.5)
@export var sunset_sky_bottom: Color = Color(1.0, 0.35, 0.15)

@export_group("Sun Colors")
@export var sun_day_color: Color = Color(1.0, 1.0, 0.8)
@export var sun_sunrise_color: Color = Color(1.0, 0.6, 0.2)
@export var sun_sunset_color: Color = Color(1.0, 0.4, 0.1)

@export_group("Night Filter")
@export var night_filter_color: Color = Color(0.15, 0.2, 0.5, 0.5)

var sun_mesh: MeshInstance3D
var sun_material: StandardMaterial3D
var moon_mesh: MeshInstance3D
var night_filter: ColorRect
var sky_mesh: MeshInstance3D
var sky_material: ShaderMaterial
var world_environment: WorldEnvironment
var environment: Environment
var camera: Camera3D
var orbit_center: Vector3 = Vector3.ZERO
var target_orbit_center: Vector3 = Vector3.ZERO
var recenter_timer: float = 0.0
var center_lerp_speed: float = 2.0  # How fast to smoothly move toward player

func _ready():
	add_to_group("day_night_cycle")
	create_sky()
	create_sun()
	create_moon()
	find_environment()
	create_night_filter()

func create_sky():
	# Create a large inverted sphere for the sky gradient
	sky_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 500.0
	sphere.height = 1000.0
	sphere.radial_segments = 32
	sphere.rings = 16
	sphere.flip_faces = true  # Render inside
	sky_mesh.mesh = sphere

	# Create gradient shader for sky
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec3 top_color : source_color = vec3(0.4, 0.6, 1.0);
uniform vec3 bottom_color : source_color = vec3(0.7, 0.85, 1.0);
uniform float horizon_blend : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	// Push sky to far plane
	POSITION = vec4(VERTEX.xy, 0.9999 * VERTEX.z, VERTEX.z);
}

void fragment() {
	// Use view direction to calculate gradient
	vec3 view_dir = normalize(VIEW);
	float height = view_dir.y * 0.5 + 0.5;  // Remap -1..1 to 0..1
	height = pow(height, horizon_blend + 0.5);  // Adjust curve
	ALBEDO = mix(bottom_color, top_color, height);
}
"""

	sky_material = ShaderMaterial.new()
	sky_material.shader = shader
	sky_material.set_shader_parameter("top_color", day_sky_top)
	sky_material.set_shader_parameter("bottom_color", day_sky_bottom)
	sky_material.set_shader_parameter("horizon_blend", 0.5)
	sky_mesh.material_override = sky_material

	sky_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sky_mesh)

func create_sun():
	sun_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = sun_size
	sphere.height = sun_size * 2
	sphere.radial_segments = 16
	sphere.rings = 8
	sun_mesh.mesh = sphere

	sun_material = StandardMaterial3D.new()
	sun_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sun_material.albedo_color = Color.WHITE
	sun_material.emission_enabled = true
	sun_material.emission = sun_day_color
	sun_material.emission_energy_multiplier = 2.0
	sun_material.render_priority = -200  # Render behind clouds
	sun_material.disable_fog = true
	sun_mesh.material_override = sun_material
	sun_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(sun_mesh)

func create_moon():
	moon_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = moon_size
	sphere.height = moon_size * 2
	sphere.radial_segments = 16
	sphere.rings = 8
	moon_mesh.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.9, 1.0)
	mat.emission_energy_multiplier = 1.5
	mat.render_priority = -200  # Render behind clouds
	mat.disable_fog = true
	moon_mesh.material_override = mat
	moon_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(moon_mesh)

func find_environment():
	world_environment = get_tree().get_first_node_in_group("world_environment")
	if not world_environment:
		world_environment = get_parent().get_parent().find_child("WorldEnvironment")
	if world_environment:
		environment = world_environment.environment

func create_night_filter():
	# Find camera
	camera = get_viewport().get_camera_3d()

	# Create CanvasLayer for the filter
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10
	add_child(canvas_layer)

	night_filter = ColorRect.new()
	night_filter.color = Color(night_filter_color.r, night_filter_color.g, night_filter_color.b, 0.0)
	night_filter.anchor_right = 1.0
	night_filter.anchor_bottom = 1.0
	night_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(night_filter)

func _process(delta):
	# Advance time
	time_of_day += delta / day_length_seconds
	if time_of_day >= 1.0:
		time_of_day -= 1.0

	update_celestial_bodies(delta)
	update_sky()
	update_ambient_and_fog()
	update_night_filter()

func update_celestial_bodies(delta: float):
	# Update target position periodically
	recenter_timer += delta
	if recenter_timer >= recenter_interval:
		recenter_timer = 0.0
		var player = get_tree().get_first_node_in_group("player")
		if player:
			target_orbit_center = player.global_position

	# Smoothly lerp orbit center toward target
	orbit_center = orbit_center.lerp(target_orbit_center, center_lerp_speed * delta)

	# Keep sky centered on orbit center
	sky_mesh.global_position = orbit_center

	# Sun angle: 0.25 (sunrise) = horizon east, 0.5 (noon) = top, 0.75 (sunset) = horizon west
	var sun_angle = (time_of_day - 0.25) * TAU  # TAU = 2*PI
	var sun_x = cos(sun_angle) * orbit_radius
	var sun_y = sin(sun_angle) * orbit_radius
	sun_mesh.global_position = orbit_center + Vector3(sun_x, sun_y, 0)

	# Moon is opposite the sun
	moon_mesh.global_position = orbit_center + Vector3(-sun_x, -sun_y, 0)

	# Hide sun/moon when below horizon
	sun_mesh.visible = sun_y > -sun_size
	moon_mesh.visible = -sun_y > -moon_size

	# Update sun color based on time
	var sun_color: Color
	if time_of_day > 0.2 and time_of_day < 0.35:
		# Sunrise - orange/yellow
		var t = (time_of_day - 0.2) / 0.15
		if t < 0.5:
			sun_color = sun_sunrise_color
		else:
			sun_color = sun_sunrise_color.lerp(sun_day_color, (t - 0.5) * 2.0)
	elif time_of_day > 0.65 and time_of_day < 0.8:
		# Sunset - orange/red
		var t = (time_of_day - 0.65) / 0.15
		if t < 0.5:
			sun_color = sun_day_color.lerp(sun_sunset_color, t * 2.0)
		else:
			sun_color = sun_sunset_color
	else:
		sun_color = sun_day_color

	sun_material.emission = sun_color

func update_sky():
	if not sky_material:
		return

	var sun_height = sin((time_of_day - 0.25) * TAU)
	var day_factor = clamp(sun_height * 2.0 + 0.5, 0.0, 1.0)

	var top_color: Color
	var bottom_color: Color

	# Check for sunrise/sunset
	if time_of_day > 0.2 and time_of_day < 0.35:
		# Sunrise
		var t = (time_of_day - 0.2) / 0.15
		if t < 0.5:
			# Night to sunrise
			top_color = night_sky_top.lerp(sunrise_sky_top, t * 2.0)
			bottom_color = night_sky_bottom.lerp(sunrise_sky_bottom, t * 2.0)
		else:
			# Sunrise to day
			top_color = sunrise_sky_top.lerp(day_sky_top, (t - 0.5) * 2.0)
			bottom_color = sunrise_sky_bottom.lerp(day_sky_bottom, (t - 0.5) * 2.0)
	elif time_of_day > 0.65 and time_of_day < 0.8:
		# Sunset
		var t = (time_of_day - 0.65) / 0.15
		if t < 0.5:
			# Day to sunset
			top_color = day_sky_top.lerp(sunset_sky_top, t * 2.0)
			bottom_color = day_sky_bottom.lerp(sunset_sky_bottom, t * 2.0)
		else:
			# Sunset to night
			top_color = sunset_sky_top.lerp(night_sky_top, (t - 0.5) * 2.0)
			bottom_color = sunset_sky_bottom.lerp(night_sky_bottom, (t - 0.5) * 2.0)
	else:
		# Normal day/night
		top_color = night_sky_top.lerp(day_sky_top, day_factor)
		bottom_color = night_sky_bottom.lerp(day_sky_bottom, day_factor)

	sky_material.set_shader_parameter("top_color", top_color)
	sky_material.set_shader_parameter("bottom_color", bottom_color)

func update_ambient_and_fog():
	if not environment:
		return

	# Calculate sun height factor (0 = horizon, 1 = noon, negative = below horizon)
	var sun_height = sin((time_of_day - 0.25) * TAU)

	# Day/night blend (0 = full night, 1 = full day)
	var day_factor = clamp(sun_height * 2.0 + 0.5, 0.0, 1.0)

	# Golden hour calculation - strongest when sun is near horizon during day
	var golden_hour_factor = 0.0
	if time_of_day > 0.2 and time_of_day < 0.35:
		# Sunrise golden hour
		var t = (time_of_day - 0.2) / 0.15
		golden_hour_factor = sin(t * PI)  # Peak at middle of transition
	elif time_of_day > 0.65 and time_of_day < 0.8:
		# Sunset golden hour
		var t = (time_of_day - 0.65) / 0.15
		golden_hour_factor = sin(t * PI)  # Peak at middle of transition

	# Ambient light with golden hour blend
	var base_ambient = night_ambient_color.lerp(day_ambient_color, day_factor)
	var final_ambient = base_ambient.lerp(golden_hour_ambient_color, golden_hour_factor * 0.7)
	environment.ambient_light_color = final_ambient

	var base_energy = lerpf(night_ambient_energy, day_ambient_energy, day_factor)
	environment.ambient_light_energy = lerpf(base_energy, golden_hour_ambient_energy, golden_hour_factor * 0.5)

	# Fog color with sunrise/sunset tints
	var base_fog = night_fog_color.lerp(day_fog_color, day_factor)

	if time_of_day > 0.2 and time_of_day < 0.35:
		# Sunrise fog
		base_fog = base_fog.lerp(sunrise_fog_color, golden_hour_factor * 0.6)
	elif time_of_day > 0.65 and time_of_day < 0.8:
		# Sunset fog
		base_fog = base_fog.lerp(sunset_fog_color, golden_hour_factor * 0.6)

	environment.fog_light_color = base_fog

func update_night_filter():
	if not night_filter:
		return

	# Calculate night intensity - more gradual and stronger
	var sun_height = sin((time_of_day - 0.25) * TAU)

	# Start filter earlier and make it stronger at full night
	var night_intensity = clamp(-sun_height * 1.2 + 0.1, 0.0, 1.0)
	night_intensity = pow(night_intensity, 0.7)  # Ease in curve for smoother transition

	night_filter.color = Color(
		night_filter_color.r,
		night_filter_color.g,
		night_filter_color.b,
		night_filter_color.a * night_intensity
	)

func get_time_string() -> String:
	var hours = int(time_of_day * 24)
	var minutes = int((time_of_day * 24 - hours) * 60)
	return "%02d:%02d" % [hours, minutes]

func is_night() -> bool:
	return time_of_day < 0.25 or time_of_day > 0.75
