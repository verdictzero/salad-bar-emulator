extends Node
class_name GameController

@onready var player: FPSController = $"../Player"
@onready var terrain_system: TerrainSystem = $"../TerrainSystem"
@onready var vegetation_system: VegetationSystem = $"../VegetationSystem"

func _ready():
	await get_tree().process_frame
	
	if player and terrain_system:
		terrain_system.set_player_position(player.position)
		
		await get_tree().process_frame
		await get_tree().process_frame
		
		var ground_height = terrain_system.get_terrain_height_at_world_position(player.position)
		player.position.y = ground_height + 2.0

func _process(_delta):
	if player and terrain_system:
		terrain_system.set_player_position(player.position)