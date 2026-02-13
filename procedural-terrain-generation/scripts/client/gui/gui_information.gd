extends Control


func _on_button_button_down() -> void:
	get_tree().change_scene_to_file("res://scenes/main/gui_main_menu.tscn")
