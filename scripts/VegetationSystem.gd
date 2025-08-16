@tool
extends Node3D
class_name VegetationSystem

@export_group("Vegetation Settings")
@export var spawn_distance: float = 100.0
@export var density: float = 0.3
@export var min_scale: float = 0.8
@export var max_scale: float = 1.5

@export_group("Clustering")
@export var use_clustering: bool = true
@export var clusters_per_chunk: int = 3
@export var vegetation_per_cluster: int = 8
@export var cluster_radius: float = 6.0

@export_group("Preview Settings")
@export var preview_enabled: bool = false : set = set_preview_enabled
@export var preview_size: int = 3 : set = set_preview_size

var spawned_vegetation: Dictionary = {}
var preview_vegetation: Array = []
var terrain_system: TerrainSystem
var vegetation_material: StandardMaterial3D
var update_timer: float = 0.0
var update_frequency: float = 1.0

func _ready():
	setup_material()
	terrain_system = get_parent().find_child("TerrainSystem")
	
	if Engine.is_editor_hint():
		if preview_enabled:
			generate_preview()
	else:
		set_process(true)

func setup_material():
	vegetation_material = StandardMaterial3D.new()
	var texture = load("res://bush.tga")
	if texture:
		vegetation_material.albedo_texture = texture
	
	vegetation_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vegetation_material.roughness = 1.0
	vegetation_material.metallic = 0.0
	vegetation_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	vegetation_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	vegetation_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

func _process(delta):
	if Engine.is_editor_hint():
		return
	
	update_timer += delta
	if update_timer >= update_frequency:
		update_vegetation()
		update_timer = 0.0

func set_preview_enabled(value: bool):
	preview_enabled = value
	if Engine.is_editor_hint():
		if preview_enabled:
			generate_preview()
		else:
			clear_preview()

func set_preview_size(value: int):
	preview_size = max(1, value)
	if Engine.is_editor_hint() and preview_enabled:
		generate_preview()

func generate_preview():
	clear_preview()
	
	var center = Vector2.ZERO
	var half_size = preview_size / 2
	
	for x in range(-half_size, half_size + 1):
		for z in range(-half_size, half_size + 1):
			var chunk_pos = Vector2(x, z)
			spawn_vegetation_in_chunk(chunk_pos, true)

func clear_preview():
	for vegetation in preview_vegetation:
		if is_instance_valid(vegetation):
			vegetation.queue_free()
	preview_vegetation.clear()

func update_vegetation():
	if not terrain_system:
		terrain_system = get_parent().find_child("TerrainSystem")
		return
	
	var player_pos = terrain_system.player_position
	var chunk_size = terrain_system.chunk_size
	
	var chunks_to_remove = []
	for chunk_key in spawned_vegetation.keys():
		var chunk_pos = str_to_var("Vector2" + chunk_key)
		var world_pos = Vector3(chunk_pos.x * chunk_size, 0, chunk_pos.y * chunk_size)
		if world_pos.distance_to(player_pos) > spawn_distance:
			chunks_to_remove.append(chunk_key)
	
	for chunk_key in chunks_to_remove:
		remove_vegetation_in_chunk(chunk_key)
	
	var player_chunk = Vector2(floor(player_pos.x / chunk_size), floor(player_pos.z / chunk_size))
	var spawn_radius = int(spawn_distance / chunk_size)
	
	for x in range(player_chunk.x - spawn_radius, player_chunk.x + spawn_radius + 1):
		for z in range(player_chunk.y - spawn_radius, player_chunk.y + spawn_radius + 1):
			var chunk_pos = Vector2(x, z)
			var chunk_key = str(chunk_pos)
			
			if chunk_key not in spawned_vegetation:
				spawn_vegetation_in_chunk(chunk_pos, false)

func spawn_vegetation_in_chunk(chunk_pos: Vector2, is_preview: bool = false):
	var chunk_key = str(chunk_pos)
	var chunk_vegetation = []
	var chunk_size = terrain_system.chunk_size if terrain_system else 32
	
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(chunk_key + "vegetation")
	
	if use_clustering:
		spawn_clustered_vegetation(chunk_pos, chunk_vegetation, rng, is_preview)
	else:
		spawn_scattered_vegetation(chunk_pos, chunk_vegetation, rng, is_preview)
	
	if is_preview:
		preview_vegetation.append_array(chunk_vegetation)
	else:
		spawned_vegetation[chunk_key] = chunk_vegetation

func spawn_clustered_vegetation(chunk_pos: Vector2, chunk_vegetation: Array, rng: RandomNumberGenerator, is_preview: bool):
	var chunk_size = terrain_system.chunk_size if terrain_system else 32
	
	for cluster_i in range(clusters_per_chunk):
		var cluster_center_x = rng.randf_range(cluster_radius, chunk_size - cluster_radius)
		var cluster_center_z = rng.randf_range(cluster_radius, chunk_size - cluster_radius)
		
		for veg_i in range(vegetation_per_cluster):
			var mesh_instance = create_vegetation_instance(rng)
			
			var distance_from_center = rng.randf_range(0, cluster_radius)
			var angle = rng.randf_range(0, 2 * PI)
			var veg_x = cluster_center_x + cos(angle) * distance_from_center
			var veg_z = cluster_center_z + sin(angle) * distance_from_center
			
			position_vegetation(mesh_instance, chunk_pos, veg_x, veg_z, distance_from_center, rng)
			
			add_child(mesh_instance)
			chunk_vegetation.append(mesh_instance)

func spawn_scattered_vegetation(chunk_pos: Vector2, chunk_vegetation: Array, rng: RandomNumberGenerator, is_preview: bool):
	var chunk_size = terrain_system.chunk_size if terrain_system else 32
	var vegetation_count = int(chunk_size * chunk_size * density / 100.0)
	
	for i in range(vegetation_count):
		var mesh_instance = create_vegetation_instance(rng)
		
		var veg_x = rng.randf_range(0, chunk_size)
		var veg_z = rng.randf_range(0, chunk_size)
		
		position_vegetation(mesh_instance, chunk_pos, veg_x, veg_z, 0, rng)
		
		add_child(mesh_instance)
		chunk_vegetation.append(mesh_instance)

func create_vegetation_instance(rng: RandomNumberGenerator) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(1.5, 1.2)
	
	mesh_instance.mesh = quad_mesh
	mesh_instance.material_override = vegetation_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	return mesh_instance

func position_vegetation(mesh_instance: MeshInstance3D, chunk_pos: Vector2, local_x: float, local_z: float, distance_from_center: float, rng: RandomNumberGenerator):
	var chunk_size = terrain_system.chunk_size if terrain_system else 32
	var world_x = chunk_pos.x * chunk_size + local_x
	var world_z = chunk_pos.y * chunk_size + local_z
	
	var height = 0.0
	if terrain_system:
		height = terrain_system.get_height_at(world_x, world_z)
	
	var scale_factor = rng.randf_range(min_scale, max_scale)
	if use_clustering:
		scale_factor = lerp(max_scale, min_scale, distance_from_center / cluster_radius)
		scale_factor *= rng.randf_range(0.8, 1.2)
	
	mesh_instance.position = Vector3(world_x, height + (scale_factor * 0.6), world_z)
	mesh_instance.scale = Vector3(scale_factor, scale_factor, scale_factor)
	mesh_instance.rotation_degrees.y = rng.randf_range(0, 360)

func remove_vegetation_in_chunk(chunk_key: String):
	if chunk_key in spawned_vegetation:
		for vegetation in spawned_vegetation[chunk_key]:
			if is_instance_valid(vegetation):
				vegetation.queue_free()
		spawned_vegetation.erase(chunk_key)