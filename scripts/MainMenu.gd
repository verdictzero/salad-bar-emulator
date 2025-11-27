extends Control
class_name MainMenu

@onready var main_container: VBoxContainer = $CenterContainer/MainContainer
@onready var controls_menu: Control = $ControlsMenu
@onready var start_button: Button = $CenterContainer/MainContainer/StartButton
@onready var controls_button: Button = $CenterContainer/MainContainer/ControlsButton
@onready var quit_button: Button = $CenterContainer/MainContainer/QuitButton
@onready var title_label: Label = $CenterContainer/MainContainer/TitleLabel

func _ready():
	# Connect button signals
	start_button.pressed.connect(_on_start_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Setup button navigation for gamepad
	setup_button_navigation()

	# Make sure controls menu is hidden initially
	if controls_menu:
		controls_menu.hide()
		controls_menu.back_to_main.connect(_on_controls_back)

	# Focus the start button for gamepad navigation
	start_button.grab_focus()

func setup_button_navigation():
	# Set up focus neighbors for D-pad navigation
	start_button.focus_neighbor_top = start_button.get_path_to(quit_button)
	start_button.focus_neighbor_bottom = start_button.get_path_to(controls_button)

	controls_button.focus_neighbor_top = controls_button.get_path_to(start_button)
	controls_button.focus_neighbor_bottom = controls_button.get_path_to(quit_button)

	quit_button.focus_neighbor_top = quit_button.get_path_to(controls_button)
	quit_button.focus_neighbor_bottom = quit_button.get_path_to(start_button)

func _on_start_pressed():
	# Load the main game scene
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_controls_pressed():
	# Show controls menu, hide main menu
	main_container.hide()
	if controls_menu:
		controls_menu.show()

func _on_controls_back():
	# Show main menu, hide controls menu
	if controls_menu:
		controls_menu.hide()
	main_container.show()
	# Re-focus start button for gamepad
	await get_tree().process_frame
	start_button.grab_focus()

func _on_quit_pressed():
	get_tree().quit()
