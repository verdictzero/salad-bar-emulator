extends CanvasLayer
class_name DebugUI

var time_label: Label
var stats_label: Label
var day_night_cycle: DayNightCycle
var update_timer: float = 0.0
var update_interval: float = 0.5  # Update stats every 0.5 seconds

func _ready():
	layer = 100  # Render on top
	create_labels()
	find_day_night_cycle()

func find_day_night_cycle():
	day_night_cycle = get_tree().get_first_node_in_group("day_night_cycle")

func create_labels():
	# Time of day label (upper left)
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 14)
	time_label.add_theme_color_override("font_color", Color(1, 1, 1))
	time_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	time_label.add_theme_constant_override("shadow_offset_x", 1)
	time_label.add_theme_constant_override("shadow_offset_y", 1)
	time_label.position = Vector2(10, 10)
	add_child(time_label)

	# Stats label (upper right)
	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(1, 1, 1))
	stats_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	stats_label.add_theme_constant_override("shadow_offset_x", 1)
	stats_label.add_theme_constant_override("shadow_offset_y", 1)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_label.position = Vector2(10, 10)
	add_child(stats_label)

func _process(delta):
	# Update time every frame (it's cheap)
	update_time_display()

	# Update stats periodically (more expensive)
	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0.0
		update_stats_display()

func update_time_display():
	if day_night_cycle:
		time_label.text = day_night_cycle.get_time_string()
	else:
		find_day_night_cycle()
		time_label.text = "--:--"

func update_stats_display():
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	var vram_mb = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var ram_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0

	var gpu_name = RenderingServer.get_video_adapter_name()
	# Shorten GPU name if too long
	if gpu_name.length() > 30:
		gpu_name = gpu_name.substr(0, 27) + "..."

	var cpu_name = OS.get_processor_name()
	# Shorten CPU name if too long
	if cpu_name.length() > 30:
		cpu_name = cpu_name.substr(0, 27) + "..."

	stats_label.text = "FPS: %d\nGPU: %s\nVRAM: %.0f MB\nCPU: %s\nRAM: %.0f MB" % [
		fps,
		gpu_name,
		vram_mb,
		cpu_name,
		ram_mb
	]

	# Position in upper right
	var viewport_size = get_viewport().get_visible_rect().size
	stats_label.position.x = viewport_size.x - stats_label.size.x - 10
