extends Control

@onready var seed_input: LineEdit = $VBoxContainer/HBoxContainer/SeedInput
@onready var octave_input: HSlider = $VBoxContainer/Octaveslider

const DEFAULT_SEED := 732647346203746

func _on_start_button_down() -> void:
	var temp_seed := seed_input.text.strip_edges()

	if temp_seed.is_valid_int():
		GameSettingsAutoload.seed = int(temp_seed)
	else:
		push_warning("Seed invalide: '%s' -> seed par défaut" % temp_seed)
		GameSettingsAutoload.seed = DEFAULT_SEED

	GameSettingsAutoload.octave = int(octave_input.value)

	var error := get_tree().change_scene_to_file("res://scenes/main/terrain_world.tscn")
	if error != OK:
		push_error("Impossible de charger terrain_world depuis settings_menu: %s (err=%s)" % error)
