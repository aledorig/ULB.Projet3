extends Control

# func _on_ready() -> void:
	# UIsounds.install_sounds(self)

func _on_play_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/main/gui_create_world.tscn")
	if error != OK:
		push_error("Failed to load gui_create_world (error=%s)" % error)


func _on_information_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/main/gui_information.tscn")
	if error != OK:
		push_error("Failed to load information (error=%s)" % error)


func _on_intermediate_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/main/intermediate_stage.tscn")
	if error != OK:
		push_error("Failed to load information (error=%s)" % error)


func _on_quit_pressed() -> void:
	get_tree().quit()
