class_name GuiIngameMenu
extends Control

@onready var settings_panel: VBoxContainer = %SettingsPanel
@onready var render_distance_slider: HSlider = %RenderDistanceSlider
@onready var render_distance_label: Label = %RenderDistanceValue
@onready var max_speed_slider: HSlider = %MaxSpeedSlider
@onready var max_speed_label: Label = %MaxSpeedValue
@onready var generation_step_slider: HSlider = %GenerationStepSlider
@onready var generation_step_label: Label = %GenerationStepValue

var settings_visible: bool = false


func _ready() -> void:
	visible = false
	settings_panel.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sync_ui_from_settings()
	render_distance_slider.value_changed.connect(_on_render_distance_changed)
	max_speed_slider.value_changed.connect(_on_max_speed_changed)
	generation_step_slider.value_changed.connect(_on_generation_step_changed)


func _sync_ui_from_settings() -> void:
	render_distance_slider.value = GameSettingsAutoload.render_distance
	render_distance_label.text = str(GameSettingsAutoload.render_distance)
	max_speed_slider.value = GameSettingsAutoload.max_speed
	max_speed_label.text = str(int(GameSettingsAutoload.max_speed))
	var step: int = GameSettingsAutoload.generation_step
	generation_step_slider.value = step
	generation_step_label.text = str(step)


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_menu"):
		if visible:
			_close_menu()
		else:
			_open_menu()


func _open_menu() -> void:
	visible = true
	settings_visible = false
	settings_panel.visible = false
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _close_menu() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_back_to_game_pressed() -> void:
	_close_menu()


func _on_settings_pressed() -> void:
	settings_visible = not settings_visible
	settings_panel.visible = settings_visible
	if settings_visible:
		_sync_ui_from_settings()


func _on_quit_to_title_pressed() -> void:
	get_tree().paused = false
	var error := get_tree().change_scene_to_file("res://scenes/main/gui_main_menu.tscn")
	if error != OK:
		push_error("Failed to load main_menu (error=%s)" % error)


func _on_render_distance_changed(value: float) -> void:
	render_distance_label.text = str(int(value))
	GameSettingsAutoload.render_distance = int(value)


func _on_max_speed_changed(value: float) -> void:
	max_speed_label.text = str(int(value))
	GameSettingsAutoload.max_speed = value


func _on_generation_step_changed(value: float) -> void:
	var step: int = int(value)
	generation_step_label.text = str(step)
	GameSettingsAutoload.generation_step = step
