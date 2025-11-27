extends Node
class_name GameSettings

# Central settings management system
signal settings_changed(setting_name: String, value)

# Terrain Settings
@export_group("Terrain Settings")
@export var chunk_size: int = 32
@export var render_distance: int = 15
@export var max_lod_level: int = 4
@export var height_scale: float = 0.1
@export var noise_scale: float = 0.01
@export var octaves: int = 4
@export var persistence: float = 0.5
@export var lacunarity: float = 2.0
@export var update_frequency: float = 0.05

# Vegetation Settings
@export_group("Vegetation Settings")
@export var spawn_distance: float = 100.0
@export var tree_density: float = 0.2
@export var bush_density: float = 0.6
@export var tree_min_scale: float = 6.0
@export var tree_max_scale: float = 12.0
@export var bush_min_scale: float = 0.8
@export var bush_max_scale: float = 1.5
@export var use_clustering: bool = true
@export var clusters_per_chunk: int = 3
@export var vegetation_per_cluster: int = 8
@export var cluster_radius: float = 6.0

# Post-Processing Settings (URSC Dithering)
@export_group("Retro Post Effects")
@export var enable_retro_effect: bool = false
@export var color_depth: float = 8.0 : set = set_color_depth

# Performance Settings
@export_group("Performance")
@export var chunks_per_frame: int = 4
@export var generation_frequency: float = 0.008
@export var show_debug_info: bool = true

var terrain_system: TerrainSystem
var vegetation_system: VegetationSystem
var post_effect: RetroPostEffect

func _ready():
	add_to_group("game_settings")
	# Find and connect to systems
	await get_tree().process_frame
	terrain_system = get_tree().get_first_node_in_group("terrain_system")
	vegetation_system = get_tree().get_first_node_in_group("vegetation_system")
	# Try to find RetroPostEffect if it exists
	var retro_nodes = get_tree().get_nodes_in_group("retro_post_effect")
	if retro_nodes.size() > 0:
		post_effect = retro_nodes[0]
	
	# Apply initial settings
	apply_all_settings()

func apply_all_settings():
	apply_terrain_settings()
	apply_vegetation_settings()
	apply_post_effect_settings()

func apply_terrain_settings():
	if not terrain_system:
		return
	
	terrain_system.chunk_size = chunk_size
	terrain_system.render_distance = render_distance
	terrain_system.max_lod_level = max_lod_level
	terrain_system.height_scale = height_scale
	terrain_system.noise_scale = noise_scale
	terrain_system.octaves = octaves
	terrain_system.persistence = persistence
	terrain_system.lacunarity = lacunarity
	terrain_system.update_frequency = update_frequency
	terrain_system.chunks_per_frame = chunks_per_frame
	terrain_system.generation_frequency = generation_frequency
	
	# Re-setup noise with new settings
	if terrain_system.has_method("setup_noise"):
		terrain_system.setup_noise()

func apply_vegetation_settings():
	if not vegetation_system:
		return
	
	vegetation_system.spawn_distance = spawn_distance
	vegetation_system.tree_density = tree_density
	vegetation_system.bush_density = bush_density
	vegetation_system.tree_min_scale = tree_min_scale
	vegetation_system.tree_max_scale = tree_max_scale
	vegetation_system.bush_min_scale = bush_min_scale
	vegetation_system.bush_max_scale = bush_max_scale
	vegetation_system.use_clustering = use_clustering
	vegetation_system.clusters_per_chunk = clusters_per_chunk
	vegetation_system.vegetation_per_cluster = vegetation_per_cluster
	vegetation_system.cluster_radius = cluster_radius

func apply_post_effect_settings():
	if not post_effect:
		return

	post_effect.set_enabled(enable_retro_effect)
	post_effect.set_color_depth(color_depth)

# Setter that automatically applies changes
func set_color_depth(value: float):
	color_depth = value
	apply_post_effect_settings()
	settings_changed.emit("color_depth", value)

# Convenience methods for runtime changes
func set_terrain_setting(setting_name: String, value):
	match setting_name:
		"height_scale":
			height_scale = value
		"render_distance":
			render_distance = value
		"tree_density":
			tree_density = value
		"bush_density":
			bush_density = value
	apply_all_settings()
	settings_changed.emit(setting_name, value)

func get_setting(setting_name: String):
	return get(setting_name)