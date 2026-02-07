# Class main_menu ui
extends Control

func _on_start_button_down() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/main/settings_menu.tscn")
	if error != OK:
		push_error("Impossible de charger settings_menu (error=%s)" % error)

func _on_information_button_down() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/main/information.tscn")
	if error != OK: 
		push_error("Impossible de charger information (err=%s)" % error)

func _on_quit_button_down() -> void:
	get_tree().quit()
