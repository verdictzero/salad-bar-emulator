@tool
extends Node3D
class_name TerrainSystem

@export_group("Terrain Settings")
@export var chunk_size: int = 32
@export var render_distance: int = 8
@export var max_lod_level: int = 3

@export_group("Height Generation")
@export var height_scale: float = 20.0
@export var noise_scale: float = 0.01
@export var octaves: int = 4
@export var persistence: float = 0.5
@export var lacunarity: float = 2.0

@export_group("Preview Settings")
@export var preview_enabled: bool = false : set = set_preview_enabled
@export var preview_size: int = 3 : set = set_preview_size
@export var auto_update: bool = true

var chunks: Dictionary = {}
var preview_chunks: Array = []
var noise: FastNoiseLite
var terrain_material: StandardMaterial3D
var player_position: Vector3 = Vector3.ZERO
var last_player_chunk: Vector2 = Vector2.INF
var update_timer: float = 0.0
var update_frequency: float = 0.5

func _ready():
	setup_noise()
	setup_material()
	
	if Engine.is_editor_hint():
		if preview_enabled:
			generate_preview()
	else:
		set_process(true)

func setup_noise():
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_scale
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = lacunarity
	noise.fractal_gain = persistence

func setup_material():
	terrain_material = StandardMaterial3D.new()
	terrain_material.albedo_color = Color.WHITE
	terrain_material.roughness = 0.8
	terrain_material.metallic = 0.0
	terrain_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	terrain_material.uv1_scale = Vector3(8.0, 8.0, 8.0)
	
	var grass_texture = load("res://grass_checkered.tga")
	if grass_texture:
		terrain_material.albedo_texture = grass_texture

func _process(delta):
	if Engine.is_editor_hint():
		return
	
	update_timer += delta
	if update_timer >= update_frequency:
		var current_chunk = world_to_chunk(player_position)
		if current_chunk.distance_to(last_player_chunk) > 1:
			update_terrain()
			last_player_chunk = current_chunk
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
			var chunk = create_preview_chunk(chunk_pos)
			preview_chunks.append(chunk)

func clear_preview():
	for chunk in preview_chunks:
		if is_instance_valid(chunk):
			chunk.queue_free()
	preview_chunks.clear()

func create_preview_chunk(chunk_pos: Vector2) -> StaticBody3D:
	var static_body = StaticBody3D.new()
	var mesh_instance = MeshInstance3D.new()
	var mesh = generate_terrain_mesh(chunk_pos, 0)
	
	mesh_instance.mesh = mesh
	mesh_instance.material_override = terrain_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	static_body.position = Vector3(chunk_pos.x * chunk_size, 0, chunk_pos.y * chunk_size)
	static_body.add_child(mesh_instance)
	add_child(static_body)
	
	return static_body

func update_terrain():
	var player_chunk = world_to_chunk(player_position)
	
	var chunks_to_remove = []
	for chunk_key in chunks.keys():
		var chunk_pos = str_to_var("Vector2" + chunk_key)
		if chunk_pos.distance_to(player_chunk) > render_distance:
			chunks_to_remove.append(chunk_key)
	
	for chunk_key in chunks_to_remove:
		remove_chunk(chunk_key)
	
	for x in range(player_chunk.x - render_distance, player_chunk.x + render_distance + 1):
		for z in range(player_chunk.y - render_distance, player_chunk.y + render_distance + 1):
			var chunk_pos = Vector2(x, z)
			var chunk_key = str(chunk_pos)
			
			if chunk_key not in chunks:
				create_chunk(chunk_pos)

func world_to_chunk(world_pos: Vector3) -> Vector2:
	return Vector2(floor(world_pos.x / chunk_size), floor(world_pos.z / chunk_size))

func create_chunk(chunk_pos: Vector2):
	var chunk_key = str(chunk_pos)
	var distance_to_player = chunk_pos.distance_to(world_to_chunk(player_position))
	var lod_level = min(int(distance_to_player / 3), max_lod_level)
	
	var static_body = StaticBody3D.new()
	var mesh_instance = MeshInstance3D.new()
	var collision_shape = CollisionShape3D.new()
	var mesh = generate_terrain_mesh(chunk_pos, lod_level)
	
	mesh_instance.mesh = mesh
	mesh_instance.material_override = terrain_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.visibility_range_end = 500.0
	
	if distance_to_player < 4:
		var shape = mesh.create_trimesh_shape()
		collision_shape.shape = shape
		static_body.add_child(collision_shape)
	
	static_body.position = Vector3(chunk_pos.x * chunk_size, 0, chunk_pos.y * chunk_size)
	static_body.add_child(mesh_instance)
	add_child(static_body)
	chunks[chunk_key] = static_body

func generate_terrain_mesh(chunk_pos: Vector2, lod_level: int) -> ArrayMesh:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	var uvs = PackedVector2Array()
	
	var step = 1 << (lod_level + 1)
	step = max(step, 1)
	var resolution = max(chunk_size / step, 2)
	
	var vertex_count = (resolution + 1) * (resolution + 1)
	vertices.resize(vertex_count)
	normals.resize(vertex_count)
	uvs.resize(vertex_count)
	
	var vertex_index = 0
	for x in range(resolution + 1):
		for z in range(resolution + 1):
			var world_x = chunk_pos.x * chunk_size + x * step
			var world_z = chunk_pos.y * chunk_size + z * step
			var height = get_height_at(world_x, world_z)
			
			vertices[vertex_index] = Vector3(x * step, height, z * step)
			normals[vertex_index] = calculate_normal(world_x, world_z)
			uvs[vertex_index] = Vector2(float(x) / resolution, float(z) / resolution)
			vertex_index += 1
	
	indices.resize(resolution * resolution * 6)
	var index_pos = 0
	for x in range(resolution):
		for z in range(resolution):
			var i = x * (resolution + 1) + z
			
			indices[index_pos] = i
			indices[index_pos + 1] = i + resolution + 1
			indices[index_pos + 2] = i + 1
			
			indices[index_pos + 3] = i + 1
			indices[index_pos + 4] = i + resolution + 1
			indices[index_pos + 5] = i + resolution + 2
			
			index_pos += 6
	
	var mesh = ArrayMesh.new()
	var surface_array = []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = vertices
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_INDEX] = indices
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)
	return mesh

func get_height_at(x: float, z: float) -> float:
	return noise.get_noise_2d(x, z) * height_scale

func calculate_normal(x: float, z: float) -> Vector3:
	var h_left = get_height_at(x - 1, z)
	var h_right = get_height_at(x + 1, z)
	var h_down = get_height_at(x, z - 1)
	var h_up = get_height_at(x, z + 1)
	
	var normal = Vector3(h_left - h_right, 2.0, h_down - h_up).normalized()
	return normal

func set_player_position(pos: Vector3):
	player_position = pos

func remove_chunk(chunk_key: String):
	if chunk_key in chunks:
		chunks[chunk_key].queue_free()
		chunks.erase(chunk_key)

func get_terrain_height_at_world_position(world_pos: Vector3) -> float:
	return get_height_at(world_pos.x, world_pos.z)