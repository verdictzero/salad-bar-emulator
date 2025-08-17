extends Node
class_name DebugLogger

static var instance: DebugLogger
static var log_file: FileAccess
static var session_start_time: String

func _init():
	instance = self

func _ready():
	setup_logging()
	add_to_group("debug_logger")

func setup_logging():
	var datetime = Time.get_datetime_dict_from_system()
	session_start_time = "%04d%02d%02d_%02d%02d%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]
	
	var log_filename = "debug_session_%s.log" % session_start_time
	log_file = FileAccess.open(log_filename, FileAccess.WRITE)
	
	if log_file == null:
		print("ERROR: Could not create log file: ", log_filename)
		return
	
	log_info("=== DEBUG SESSION STARTED ===")
	log_info("Timestamp: %s" % session_start_time)
	log_info("Godot Version: %s" % Engine.get_version_info())

static func log_info(message: String):
	var timestamp = Time.get_time_string_from_system()
	var full_message = "[%s] INFO: %s" % [timestamp, message]
	print(full_message)
	if log_file:
		log_file.store_line(full_message)
		log_file.flush()

static func log_warning(message: String):
	var timestamp = Time.get_time_string_from_system()
	var full_message = "[%s] WARNING: %s" % [timestamp, message]
	print_rich("[color=yellow]%s[/color]" % full_message)
	if log_file:
		log_file.store_line(full_message)
		log_file.flush()

static func log_error(message: String):
	var timestamp = Time.get_time_string_from_system()
	var full_message = "[%s] ERROR: %s" % [timestamp, message]
	print_rich("[color=red]%s[/color]" % full_message)
	if log_file:
		log_file.store_line(full_message)
		log_file.flush()

static func log_terrain(message: String):
	var timestamp = Time.get_time_string_from_system()
	var full_message = "[%s] TERRAIN: %s" % [timestamp, message]
	print_rich("[color=cyan]%s[/color]" % full_message)
	if log_file:
		log_file.store_line(full_message)
		log_file.flush()

static func log_player(message: String):
	var timestamp = Time.get_time_string_from_system()
	var full_message = "[%s] PLAYER: %s" % [timestamp, message]
	print_rich("[color=green]%s[/color]" % full_message)
	if log_file:
		log_file.store_line(full_message)
		log_file.flush()

func _exit_tree():
	if log_file:
		log_info("=== DEBUG SESSION ENDED ===")
		log_file.close()