class_name GuiLoadingWorld
extends Control

const TERRAIN_SCENE_PATH := "res://scenes/main/terrain_world.tscn"

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var status_label: Label = %StatusLabel

var loading_started: bool = false

func _ready() -> void:
	status_label.text = "Building terrain..."
	progress_bar.value = 0.0
	ResourceLoader.load_threaded_request(TERRAIN_SCENE_PATH)
	loading_started = true


func _process(_delta: float) -> void:
	if not loading_started:
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(TERRAIN_SCENE_PATH, progress)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress_bar.value = progress[0] * 100.0
			if progress[0] > 0.8:
				status_label.text = "Almost there..."
			elif progress[0] > 0.4:
				status_label.text = "Loading world..."
		ResourceLoader.THREAD_LOAD_LOADED:
			progress_bar.value = 100.0
			status_label.text = "Done!"
			var scene: PackedScene = ResourceLoader.load_threaded_get(TERRAIN_SCENE_PATH)
			get_tree().change_scene_to_packed(scene)
			loading_started = false
		ResourceLoader.THREAD_LOAD_FAILED:
			status_label.text = "Failed to load world!"
			push_error("GuiLoadingWorld: Failed to load terrain scene")
			loading_started = false
