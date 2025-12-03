@tool
extends Node3D
class_name VegetationSystem

@export_group("Vegetation Settings")
@export var spawn_distance: float = 100.0
@export var tree_density: float = 0.2
@export var bush_density: float = 0.6

@export_group("Tree Settings")
@export var tree_min_scale: float = 10.0
@export var tree_max_scale: float = 18.0

@export_group("Bush Settings")
@export var bush_min_scale: float = 0.8
@export var bush_max_scale: float = 1.5

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
var tree_material: StandardMaterial3D
var bush_material: StandardMaterial3D
var update_timer: float = 0.0
var update_frequency: float = 1.0
var world_offset: Vector3 = Vector3.ZERO  # Cumulative offset from origin shifting

enum VegetationType { TREE, BUSH }

func _ready():
	add_to_group("vegetation_system")
	setup_materials()
	terrain_system = get_parent().find_child("TerrainSystem")
	
	if Engine.is_editor_hint():
		if preview_enabled:
			generate_preview()
	else:
		set_process(true)

func setup_materials():
	# Tree material
	tree_material = StandardMaterial3D.new()
	var tree_texture = load("res://tree.tga")
	if tree_texture:
		tree_material.albedo_texture = tree_texture
	tree_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	tree_material.roughness = 1.0
	tree_material.metallic = 0.0
	tree_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	tree_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	tree_material.flags_unshaded = true
	tree_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	tree_material.no_depth_test = false
	tree_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	
	# Bush material
	bush_material = StandardMaterial3D.new()
	var bush_texture = load("res://bush.tga")
	if bush_texture:
		bush_material.albedo_texture = bush_texture
	bush_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	bush_material.roughness = 1.0
	bush_material.metallic = 0.0
	bush_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	bush_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bush_material.flags_unshaded = true
	bush_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bush_material.no_depth_test = false
	bush_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY

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

	# Use true world chunk position for seed to ensure consistent vegetation after origin shifts
	var true_chunk_pos = chunk_pos + Vector2(world_offset.x, world_offset.z) / chunk_size
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(str(true_chunk_pos) + "vegetation")
	
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
		
		# Spawn trees (fewer, larger)
		var tree_count = max(1, int(vegetation_per_cluster * tree_density))
		for veg_i in range(tree_count):
			var mesh_instance = create_vegetation_instance(VegetationType.TREE, rng)
			
			var distance_from_center = rng.randf_range(0, cluster_radius)
			var angle = rng.randf_range(0, 2 * PI)
			var veg_x = cluster_center_x + cos(angle) * distance_from_center
			var veg_z = cluster_center_z + sin(angle) * distance_from_center
			
			position_vegetation(mesh_instance, chunk_pos, veg_x, veg_z, distance_from_center, rng, VegetationType.TREE)
			
			add_child(mesh_instance)
			chunk_vegetation.append(mesh_instance)
		
		# Spawn bushes (more numerous, smaller)
		var bush_count = max(1, int(vegetation_per_cluster * bush_density))
		for veg_i in range(bush_count):
			var mesh_instance = create_vegetation_instance(VegetationType.BUSH, rng)
			
			var distance_from_center = rng.randf_range(0, cluster_radius)
			var angle = rng.randf_range(0, 2 * PI)
			var veg_x = cluster_center_x + cos(angle) * distance_from_center
			var veg_z = cluster_center_z + sin(angle) * distance_from_center
			
			position_vegetation(mesh_instance, chunk_pos, veg_x, veg_z, distance_from_center, rng, VegetationType.BUSH)
			
			add_child(mesh_instance)
			chunk_vegetation.append(mesh_instance)

func spawn_scattered_vegetation(chunk_pos: Vector2, chunk_vegetation: Array, rng: RandomNumberGenerator, is_preview: bool):
	var chunk_size = terrain_system.chunk_size if terrain_system else 32
	var tree_count = int(chunk_size * chunk_size * tree_density / 100.0)
	var bush_count = int(chunk_size * chunk_size * bush_density / 100.0)
	
	# Spawn trees
	for i in range(tree_count):
		var mesh_instance = create_vegetation_instance(VegetationType.TREE, rng)
		
		var veg_x = rng.randf_range(0, chunk_size)
		var veg_z = rng.randf_range(0, chunk_size)
		
		position_vegetation(mesh_instance, chunk_pos, veg_x, veg_z, 0, rng, VegetationType.TREE)
		
		add_child(mesh_instance)
		chunk_vegetation.append(mesh_instance)
	
	# Spawn bushes
	for i in range(bush_count):
		var mesh_instance = create_vegetation_instance(VegetationType.BUSH, rng)
		
		var veg_x = rng.randf_range(0, chunk_size)
		var veg_z = rng.randf_range(0, chunk_size)
		
		position_vegetation(mesh_instance, chunk_pos, veg_x, veg_z, 0, rng, VegetationType.BUSH)
		
		add_child(mesh_instance)
		chunk_vegetation.append(mesh_instance)

func create_vegetation_instance(type: VegetationType, rng: RandomNumberGenerator) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var quad_mesh = QuadMesh.new()
	
	match type:
		VegetationType.TREE:
			quad_mesh.size = Vector2(7.0, 10.0)
			quad_mesh.center_offset = Vector3(0, quad_mesh.size.y * 0.5, 0)  # Pivot at bottom
			mesh_instance.material_override = tree_material
		VegetationType.BUSH:
			quad_mesh.size = Vector2(1.5, 1.2)
			quad_mesh.center_offset = Vector3(0, quad_mesh.size.y * 0.5, 0)  # Pivot at bottom
			mesh_instance.material_override = bush_material
	
	mesh_instance.mesh = quad_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	# Set sorting offset based on vegetation type for proper depth sorting
	match type:
		VegetationType.TREE:
			mesh_instance.sorting_offset = 1.0  # Trees render behind bushes
		VegetationType.BUSH:
			mesh_instance.sorting_offset = 0.0  # Bushes render in front
	
	return mesh_instance

func position_vegetation(mesh_instance: MeshInstance3D, chunk_pos: Vector2, local_x: float, local_z: float, distance_from_center: float, rng: RandomNumberGenerator, type: VegetationType):
	var chunk_size = terrain_system.chunk_size if terrain_system else 32
	var world_x = chunk_pos.x * chunk_size + local_x
	var world_z = chunk_pos.y * chunk_size + local_z
	
	var height = 0.0
	if terrain_system:
		height = terrain_system.get_height_at(world_x, world_z)
	
	var scale_factor: float
	var height_offset: float
	
	match type:
		VegetationType.TREE:
			scale_factor = rng.randf_range(tree_min_scale, tree_max_scale)
			height_offset = -0.1  # Sink slightly into terrain for better ground contact
		VegetationType.BUSH:
			scale_factor = rng.randf_range(bush_min_scale, bush_max_scale)
			height_offset = -0.05  # Sink slightly into terrain for better ground contact
	
	if use_clustering:
		scale_factor = lerp(scale_factor, scale_factor * 0.7, distance_from_center / cluster_radius)
		scale_factor *= rng.randf_range(0.8, 1.2)
	
	mesh_instance.position = Vector3(world_x, height + height_offset, world_z)
	mesh_instance.scale = Vector3(scale_factor, scale_factor, scale_factor)
	mesh_instance.rotation_degrees.y = rng.randf_range(0, 360)

func remove_vegetation_in_chunk(chunk_key: String):
	if chunk_key in spawned_vegetation:
		for vegetation in spawned_vegetation[chunk_key]:
			if is_instance_valid(vegetation):
				vegetation.queue_free()
		spawned_vegetation.erase(chunk_key)

func get_debug_info() -> Dictionary:
	var total_vegetation = 0
	var total_trees = 0
	var total_bushes = 0
	
	for chunk_key in spawned_vegetation.keys():
		var chunk_veg = spawned_vegetation[chunk_key]
		total_vegetation += chunk_veg.size()
		for veg in chunk_veg:
			if is_instance_valid(veg) and veg.material_override == tree_material:
				total_trees += 1
			elif is_instance_valid(veg) and veg.material_override == bush_material:
				total_bushes += 1
	
	return {
		"chunks_with_vegetation": spawned_vegetation.size(),
		"total_vegetation": total_vegetation,
		"trees": total_trees,
		"bushes": total_bushes,
		"tree_density": tree_density,
		"bush_density": bush_density,
		"spawn_distance": spawn_distance
	}