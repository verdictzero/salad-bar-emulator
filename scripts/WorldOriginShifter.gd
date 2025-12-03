extends Node
class_name WorldOriginShifter

@export var shift_threshold: float = 2000.0  # Distance from origin before rebasing
@export var shift_interval: float = 1.0  # How often to check (seconds)

signal origin_shifted(offset: Vector3)

var total_offset: Vector3 = Vector3.ZERO  # Cumulative offset for world-space calculations
var shift_timer: float = 0.0
var player: Node3D

func _ready():
	add_to_group("world_origin_shifter")

func _process(delta):
	shift_timer += delta
	if shift_timer < shift_interval:
		return
	shift_timer = 0.0

	if not player:
		player = get_tree().get_first_node_in_group("player")
		return

	var distance_from_origin = Vector2(player.global_position.x, player.global_position.z).length()

	if distance_from_origin > shift_threshold:
		perform_origin_shift()

func perform_origin_shift():
	if not player:
		return

	# Calculate shift offset (move everything so player is at origin on XZ plane)
	var shift_offset = Vector3(player.global_position.x, 0, player.global_position.z)
	total_offset += shift_offset

	DebugLogger.log_terrain("ORIGIN SHIFT: Moving world by %s (total offset: %s)" % [str(shift_offset), str(total_offset)])

	# Shift player
	player.global_position -= shift_offset

	# Shift terrain chunks
	var terrain_system = get_tree().get_first_node_in_group("terrain_system")
	if terrain_system:
		shift_terrain(terrain_system, shift_offset)

	# Shift vegetation
	var vegetation_system = get_tree().get_first_node_in_group("vegetation_system")
	if vegetation_system:
		shift_vegetation(vegetation_system, shift_offset)

	# Shift day/night cycle center
	var day_night = get_tree().get_first_node_in_group("day_night_cycle")
	if day_night:
		day_night.orbit_center -= shift_offset
		day_night.target_orbit_center -= shift_offset

	# Shift cloud ring center
	var cloud_ring = get_tree().get_first_node_in_group("cloud_ring")
	if cloud_ring:
		cloud_ring.ring_center -= shift_offset
		cloud_ring.target_ring_center -= shift_offset

	# Emit signal for any other systems that need to know
	origin_shifted.emit(shift_offset)

func shift_terrain(terrain_system: TerrainSystem, offset: Vector3):
	# Update player position tracking in terrain system
	terrain_system.player_position -= offset

	# Update world offset for consistent noise sampling
	terrain_system.world_offset += offset

	# Shift all existing chunks
	for chunk_key in terrain_system.chunks.keys():
		var chunk = terrain_system.chunks[chunk_key]
		if is_instance_valid(chunk):
			chunk.global_position -= offset

func shift_vegetation(vegetation_system: VegetationSystem, offset: Vector3):
	# Update world offset for consistent seed generation
	vegetation_system.world_offset += offset

	# Shift all spawned vegetation
	for chunk_key in vegetation_system.spawned_vegetation.keys():
		var vegetation_list = vegetation_system.spawned_vegetation[chunk_key]
		for veg in vegetation_list:
			if is_instance_valid(veg):
				veg.global_position -= offset

# Convert local position to true world position (accounting for all shifts)
func local_to_world(local_pos: Vector3) -> Vector3:
	return local_pos + total_offset

# Convert true world position to local position
func world_to_local(world_pos: Vector3) -> Vector3:
	return world_pos - total_offset

# Get player's true world position (for seed-based generation)
func get_true_world_position(node: Node3D) -> Vector3:
	return node.global_position + total_offset
