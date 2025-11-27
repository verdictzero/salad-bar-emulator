extends CanvasLayer
class_name RetroPostEffect

var shader_material: ShaderMaterial
var color_rect: ColorRect

func _ready():
	add_to_group("retro_post_effect")
	# Create the post-processing overlay
	setup_post_effect()

	# Connect to settings changes
	var game_settings = get_tree().get_first_node_in_group("game_settings")
	if game_settings:
		game_settings.settings_changed.connect(_on_settings_changed)

func setup_post_effect():
	# Create ColorRect that covers the entire screen
	color_rect = ColorRect.new()
	color_rect.name = "RetroEffect"
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Load and apply the URSC dithering shader
	var shader = load("res://ursc/canvas_item/dithering.gdshader") as Shader
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	
	# Set initial shader parameters for URSC dithering
	shader_material.set_shader_parameter("color_depth", 8.0)  # 8-bit color depth for retro feel
	
	color_rect.material = shader_material
	add_child(color_rect)

func _on_settings_changed(setting_name: String, value):
	if not shader_material:
		return
	
	match setting_name:
		"color_depth":
			shader_material.set_shader_parameter("color_depth", value)

func set_enabled(enabled: bool):
	if shader_material:
		# For URSC dithering, we use color_depth 0 to disable, >0 to enable
		if enabled:
			shader_material.set_shader_parameter("color_depth", 8.0)
		else:
			shader_material.set_shader_parameter("color_depth", 0.0)

func set_color_depth(depth: float):
	if shader_material:
		shader_material.set_shader_parameter("color_depth", depth)

# Keep these for compatibility but map to color_depth
func set_pixelation(scale: float):
	# Map pixelation to color depth (higher scale = lower color depth)
	var color_depth = max(1.0, 32.0 / scale)
	set_color_depth(color_depth)

func set_dithering(strength: float):
	# Map dithering strength to color depth
	var color_depth = lerp(24.0, 4.0, strength)
	set_color_depth(color_depth)

func set_color_reduction(levels: int):
	# Direct mapping
	set_color_depth(float(levels))

func set_contrast(boost: float):
	# URSC dithering doesn't have contrast, so we ignore this
	pass
