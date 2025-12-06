extends Node3D
class_name DayNightCycle

@export_group("Cycle Settings")
@export var day_length_seconds: float = 120.0  # Full day/night cycle duration
@export var time_of_day: float = 0.25  # 0.0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset


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


@export_group("Night Filter")
@export var night_filter_color: Color = Color(0.15, 0.2, 0.5, 0.5)

var night_filter: ColorRect
var sky_shader: Shader
var sky_material: ShaderMaterial
var world_environment: WorldEnvironment
var environment: Environment
var camera: Camera3D

func _ready():
	add_to_group("day_night_cycle")
	create_sky()
	find_environment()
	create_night_filter()

func create_sky():
	# Create sky shader for use with WorldEnvironment
	sky_shader = Shader.new()
	sky_shader.code = """
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.4, 0.6, 1.0);
uniform vec3 bottom_color : source_color = vec3(0.7, 0.85, 1.0);
uniform float horizon_blend : hint_range(0.0, 1.0) = 0.5;

void sky() {
	float height = EYEDIR.y * 0.5 + 0.5;
	height = pow(height, horizon_blend + 0.5);
	COLOR = mix(bottom_color, top_color, height);
}
"""
	sky_material = ShaderMaterial.new()
	sky_material.shader = sky_shader
	sky_material.set_shader_parameter("top_color", day_sky_top)
	sky_material.set_shader_parameter("bottom_color", day_sky_bottom)
	sky_material.set_shader_parameter("horizon_blend", 0.5)

func find_environment():
	world_environment = get_tree().get_first_node_in_group("world_environment")
	if not world_environment:
		world_environment = get_parent().get_parent().find_child("WorldEnvironment")
	if world_environment:
		environment = world_environment.environment
		# Set up sky with our shader
		if environment:
			var sky = Sky.new()
			sky.sky_material = sky_material
			environment.sky = sky
			environment.background_mode = Environment.BG_SKY

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

	update_sky()
	update_ambient_and_fog()
	update_night_filter()

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
