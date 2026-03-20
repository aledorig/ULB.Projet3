class_name GuiLoadingWorld
extends CanvasLayer

const TERRAIN_SCENE_PATH := "res://scenes/main/terrain_world.tscn"

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var status_label: Label = %StatusLabel
@onready var hint_label: Label = %Hint

enum Phase { LOADING_RESOURCE, BUILDING_TERRAIN }
var phase: Phase = Phase.LOADING_RESOURCE
var chunk_manager: ChunkManager = null


func _ready() -> void:
	layer = 100
	status_label.text = "Loading resources..."
	progress_bar.value = 0.0
	hint_label.text = "Preparing scene data..."
	ResourceLoader.load_threaded_request(TERRAIN_SCENE_PATH)


func _process(_delta: float) -> void:
	match phase:
		Phase.LOADING_RESOURCE:
			_process_resource_loading()
		Phase.BUILDING_TERRAIN:
			_process_terrain_building()


func _process_resource_loading() -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(TERRAIN_SCENE_PATH, progress)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress_bar.value = progress[0] * 50.0
			if progress[0] > 0.5:
				status_label.text = "Loading assets..."
		ResourceLoader.THREAD_LOAD_LOADED:
			progress_bar.value = 50.0
			status_label.text = "Building terrain..."
			hint_label.text = "Generating chunks..."
			_start_terrain_scene()
		ResourceLoader.THREAD_LOAD_FAILED:
			status_label.text = "Failed to load world!"
			push_error("GuiLoadingWorld: Failed to load terrain scene")


func _start_terrain_scene() -> void:
	var scene: PackedScene = ResourceLoader.load_threaded_get(TERRAIN_SCENE_PATH)
	var terrain_root: Node = scene.instantiate()
	get_tree().root.add_child(terrain_root)
	get_tree().current_scene = terrain_root

	chunk_manager = terrain_root as ChunkManager
	if chunk_manager:
		chunk_manager.initial_chunks_ready.connect(_on_chunks_ready)
	else:
		push_error("GuiLoadingWorld: TerrainWorld root is not ChunkManager")
		_finish()
		return

	phase = Phase.BUILDING_TERRAIN


func _process_terrain_building() -> void:
	if not chunk_manager:
		return

	var loaded := chunk_manager.loaded_chunks.size()
	var pending := chunk_manager.pending_chunks.size()

	var total := loaded + pending
	if total > 0:
		progress_bar.value = 50.0 + (float(loaded) / float(total)) * 50.0
		status_label.text = "Building terrain... (%d/%d)" % [loaded, total]


func _on_chunks_ready() -> void:
	progress_bar.value = 100.0
	status_label.text = "Done!"
	await get_tree().create_timer(0.5).timeout
	_finish()


func _finish() -> void:
	queue_free()
