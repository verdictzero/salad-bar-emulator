@tool
extends Node3D
class_name TerrainSystem

@export_group("Terrain Settings")
@export var chunk_size: int = 32
@export var render_distance: int = 10
@export var chunk_buffer: int = 5  # Extra chunks to keep loaded beyond render distance
@export var max_lod_level: int = 4

@export_group("Height Generation")
@export var height_scale: float = 0.1
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
var update_frequency: float = 0.2  # Reduced frequency for better performance
var world_offset: Vector3 = Vector3.ZERO  # Cumulative offset from origin shifting

# Async chunk generation
var chunk_generation_queue: Array = []
var chunks_per_frame: int = 4  # Limit chunks generated per frame
var generation_timer: float = 0.0
var generation_frequency: float = 0.008  # More frequent generation

func _ready():
	add_to_group("terrain_system")
	setup_noise()
	setup_material()
	DebugLogger.log_terrain("TerrainSystem initialized - chunk_size: %d, render_distance: %d" % [chunk_size, render_distance])
	
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
	terrain_material.flags_unshaded = true
	terrain_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	terrain_material.uv1_scale = Vector3(16.0, 16.0, 16.0)
	
	var grass_texture = load("res://grass_checkered.tga")
	if grass_texture:
		terrain_material.albedo_texture = grass_texture

func _process(delta):
	if Engine.is_editor_hint():
		return
	
	# Update terrain chunks
	update_timer += delta
	if update_timer >= update_frequency:
		var current_chunk = world_to_chunk(player_position)
		# Only update when player moves to a significantly different chunk (hysteresis)
		if current_chunk.distance_to(last_player_chunk) > 1.0:
			queue_terrain_updates()
			last_player_chunk = current_chunk
		update_timer = 0.0
	
	# Process chunk generation queue
	generation_timer += delta
	if generation_timer >= generation_frequency and chunk_generation_queue.size() > 0:
		process_chunk_generation_queue()
		generation_timer = 0.0

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

func queue_terrain_updates():
	var player_chunk = world_to_chunk(player_position)
	DebugLogger.log_terrain("Updating terrain for player chunk: %s (player pos: %s)" % [str(player_chunk), str(player_position)])
	
	# Remove chunks beyond buffer zone (render_distance + chunk_buffer)
	var max_distance = render_distance + chunk_buffer
	var chunks_to_remove = []
	for chunk_key in chunks.keys():
		var chunk_pos = str_to_vector2(chunk_key)
		var distance = chunk_pos.distance_to(player_chunk)
		if distance > max_distance:
			chunks_to_remove.append(chunk_key)
		elif chunk_pos == player_chunk:
			DebugLogger.log_terrain("Player chunk %s distance: %.2f (max_distance: %d)" % [chunk_key, distance, max_distance])
	
	if chunks_to_remove.size() > 0:
		DebugLogger.log_terrain("Removing %d distant chunks" % chunks_to_remove.size())
	
	for chunk_key in chunks_to_remove:
		var chunk_pos = str_to_vector2(chunk_key)
		var distance = chunk_pos.distance_to(player_chunk)
		DebugLogger.log_terrain("Removing chunk %s at distance %.2f (player: %s)" % [chunk_key, distance, str(player_chunk)])
		remove_chunk(chunk_key)
	
	# Queue missing chunks for generation (prioritize closer chunks)
	var chunks_needed = []
	# Generate chunks within render distance, but keep buffer zone chunks if they exist
	for x in range(player_chunk.x - render_distance, player_chunk.x + render_distance + 1):
		for z in range(player_chunk.y - render_distance, player_chunk.y + render_distance + 1):
			var chunk_pos = Vector2(x, z)
			var chunk_key = str(chunk_pos)
			
			if chunk_key not in chunks and chunk_pos not in chunk_generation_queue:
				var distance = chunk_pos.distance_to(player_chunk)
				# Only generate chunks within render distance (not buffer)
				if distance <= render_distance:
					chunks_needed.append({"pos": chunk_pos, "distance": distance})
	
	# Sort by distance (closest first) and add to queue
	chunks_needed.sort_custom(func(a, b): return a.distance < b.distance)
	if chunks_needed.size() > 0:
		DebugLogger.log_terrain("Queuing %d new chunks for generation" % chunks_needed.size())
	for chunk_data in chunks_needed:
		chunk_generation_queue.append(chunk_data.pos)
		DebugLogger.log_terrain("Queued chunk: %s (distance: %.2f)" % [str(chunk_data.pos), chunk_data.distance])

func process_chunk_generation_queue():
	var chunks_generated = 0
	while chunk_generation_queue.size() > 0 and chunks_generated < chunks_per_frame:
		var chunk_pos = chunk_generation_queue.pop_front()
		var chunk_key = str(chunk_pos)
		
		# Double-check chunk isn't already created and is still needed
		var player_chunk = world_to_chunk(player_position)
		var distance_now = chunk_pos.distance_to(player_chunk)
		
		if chunk_key not in chunks and distance_now <= render_distance:
			create_chunk(chunk_pos)
			chunks_generated += 1

func world_to_chunk(world_pos: Vector3) -> Vector2:
	return Vector2(floor(world_pos.x / chunk_size), floor(world_pos.z / chunk_size))

func str_to_vector2(chunk_key: String) -> Vector2:
	# Parse chunk key like "(1.0, -2.0)" back to Vector2
	var clean_key = chunk_key.strip_edges().substr(1, chunk_key.length() - 2)  # Remove ( )
	var parts = clean_key.split(", ")
	if parts.size() == 2:
		return Vector2(float(parts[0]), float(parts[1]))
	else:
		DebugLogger.log_error("Failed to parse chunk key: %s" % chunk_key)
		return Vector2.ZERO

func create_chunk(chunk_pos: Vector2):
	var chunk_key = str(chunk_pos)
	var distance_to_player = chunk_pos.distance_to(world_to_chunk(player_position))
	DebugLogger.log_terrain("Creating chunk: %s at distance %.2f" % [str(chunk_pos), distance_to_player])
	# More aggressive LOD based on distance
	var lod_level = 0
	if distance_to_player > 7:
		lod_level = 4
	elif distance_to_player > 5:
		lod_level = 3
	elif distance_to_player > 3:
		lod_level = 2
	elif distance_to_player > 1:
		lod_level = 1
	else:
		lod_level = 0
	
	var static_body = StaticBody3D.new()
	var mesh_instance = MeshInstance3D.new()
	var collision_shape = CollisionShape3D.new()
	var mesh = generate_terrain_mesh(chunk_pos, lod_level)
	
	if mesh == null:
		DebugLogger.log_error("Failed to generate mesh for chunk %s!" % str(chunk_pos))
		return
	
	mesh_instance.mesh = mesh
	mesh_instance.material_override = terrain_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.visibility_range_end = 500.0
	
	# Use trimesh collision for all nearby chunks - the core issue might be trimesh generation
	var shape = mesh.create_trimesh_shape()
	if shape == null:
		DebugLogger.log_error("Failed to create trimesh shape for chunk %s! Using box instead." % str(chunk_pos))
		# Fallback to box collision if trimesh fails
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(chunk_size, 8.0, chunk_size)
		collision_shape.shape = box_shape
		collision_shape.position.y = 0.0
	else:
		collision_shape.shape = shape
		DebugLogger.log_terrain("Chunk %s: TRIMESH collision created successfully (distance: %.2f, vertices: %d)" % [
			str(chunk_pos), distance_to_player, shape.get_faces().size() / 3
		])
	
	# Set position BEFORE adding children to ensure proper collision positioning
	static_body.position = Vector3(chunk_pos.x * chunk_size, 0, chunk_pos.y * chunk_size)
	static_body.add_child(collision_shape)
	static_body.add_child(mesh_instance)
	add_child(static_body)
	chunks[chunk_key] = static_body
	DebugLogger.log_terrain("Chunk created successfully: %s at world pos %s (total chunks: %d)" % [chunk_key, str(static_body.position), chunks.size()])

func generate_terrain_mesh(chunk_pos: Vector2, lod_level: int) -> ArrayMesh:
	var step = 1 << (lod_level + 1)
	step = max(step, 1)
	var resolution = max(chunk_size / step, 2)
	
	var vertex_count = (resolution + 1) * (resolution + 1)
	var index_count = resolution * resolution * 6
	
	# Pre-allocate arrays for better performance
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	var uvs = PackedVector2Array()
	
	vertices.resize(vertex_count)
	normals.resize(vertex_count)
	uvs.resize(vertex_count)
	indices.resize(index_count)
	
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
	# Use true world coordinates for consistent terrain regardless of origin shifts
	var true_x = x + world_offset.x
	var true_z = z + world_offset.z
	return noise.get_noise_2d(true_x, true_z) * height_scale

func calculate_normal(x: float, z: float) -> Vector3:
	var h_left = get_height_at(x - 1, z)
	var h_right = get_height_at(x + 1, z)
	var h_down = get_height_at(x, z - 1)
	var h_up = get_height_at(x, z + 1)
	
	var normal = Vector3(h_left - h_right, 2.0, h_down - h_up).normalized()
	return normal

func set_player_position(pos: Vector3):
	var old_chunk = world_to_chunk(player_position)
	player_position = pos
	var new_chunk = world_to_chunk(player_position)
	
	if old_chunk != new_chunk:
		DebugLogger.log_terrain("Player moved to new chunk: %s (was %s)" % [str(new_chunk), str(old_chunk)])

func remove_chunk(chunk_key: String):
	if chunk_key in chunks:
		DebugLogger.log_terrain("Removing chunk: %s" % chunk_key)
		chunks[chunk_key].queue_free()
		chunks.erase(chunk_key)
	else:
		DebugLogger.log_warning("Attempted to remove non-existent chunk: %s" % chunk_key)

func get_terrain_height_at_world_position(world_pos: Vector3) -> float:
	return get_height_at(world_pos.x, world_pos.z)

func get_debug_info() -> Dictionary:
	return {
		"chunks_loaded": chunks.size(),
		"chunks_queued": chunk_generation_queue.size(),
		"player_chunk": world_to_chunk(player_position),
		"render_distance": render_distance,
		"chunk_size": chunk_size,
		"height_scale": height_scale,
		"update_frequency": update_frequency
	}
