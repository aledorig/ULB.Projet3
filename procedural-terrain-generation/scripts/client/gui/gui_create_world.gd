extends Control

@onready var seed_input: LineEdit = %SeedInput
@onready var random_seed_check: CheckBox = %RandomSeedCheck
@onready var advanced_container: VBoxContainer = %AdvancedOptions
@onready var advanced_toggle: Button = %AdvancedToggle
@onready var octave_slider: HSlider = %OctaveSlider
@onready var octave_label: Label = %OctaveValue
@onready var biome_size_slider: HSlider = %BiomeSizeSlider
@onready var biome_size_label: Label = %BiomeSizeValue
@onready var render_distance_slider: HSlider = %RenderDistanceSlider
@onready var render_distance_label: Label = %RenderDistanceValue
@onready var biome_blending_check: CheckBox = %BiomeBlendingCheck
@onready var blend_radius_slider: HSlider = %BlendRadiusSlider
@onready var blend_radius_label: Label = %BlendRadiusValue
@onready var chunk_size_slider: HSlider = %ChunkSizeSlider
@onready var chunk_size_label: Label = %ChunkSizeValue
@onready var vertex_spacing_slider: HSlider = %VertexSpacingSlider
@onready var vertex_spacing_label: Label = %VertexSpacingValue
@onready var worker_threads_slider: HSlider = %WorkerThreadsSlider
@onready var worker_threads_label: Label = %WorkerThreadsValue

var advanced_visible: bool = false

func _on_ready() -> void:
	UIsounds.install_sounds(self)
	
func _ready() -> void:
	advanced_container.visible = false
	_sync_ui_from_settings()
	octave_slider.value_changed.connect(_on_octave_changed)
	biome_size_slider.value_changed.connect(_on_biome_size_changed)
	render_distance_slider.value_changed.connect(_on_render_distance_changed)
	blend_radius_slider.value_changed.connect(_on_blend_radius_changed)
	chunk_size_slider.value_changed.connect(_on_chunk_size_changed)
	vertex_spacing_slider.value_changed.connect(_on_vertex_spacing_changed)
	worker_threads_slider.value_changed.connect(_on_worker_threads_changed)
	random_seed_check.toggled.connect(_on_random_seed_toggled)


func _sync_ui_from_settings() -> void:
	seed_input.text = str(GameSettingsAutoload.seed)
	octave_slider.value = GameSettingsAutoload.octave
	octave_label.text = str(GameSettingsAutoload.octave)
	biome_size_slider.value = GameSettingsAutoload.biome_size
	biome_size_label.text = str(GameSettingsAutoload.biome_size)
	render_distance_slider.value = GameSettingsAutoload.render_distance
	render_distance_label.text = str(GameSettingsAutoload.render_distance)
	biome_blending_check.button_pressed = GameSettingsAutoload.biome_blending
	blend_radius_slider.value = GameSettingsAutoload.blend_radius
	blend_radius_label.text = str(int(GameSettingsAutoload.blend_radius))
	chunk_size_slider.value = GameSettingsAutoload.chunk_size
	chunk_size_label.text = str(GameSettingsAutoload.chunk_size)
	vertex_spacing_slider.value = GameSettingsAutoload.vertex_spacing
	vertex_spacing_label.text = str(GameSettingsAutoload.vertex_spacing)
	worker_threads_slider.value = GameSettingsAutoload.max_worker_threads
	worker_threads_label.text = str(GameSettingsAutoload.max_worker_threads)


func _on_advanced_toggle_pressed() -> void:
	advanced_visible = not advanced_visible
	advanced_container.visible = advanced_visible
	advanced_toggle.text = "Masquer la Configuration Avancée" if advanced_visible else "Configuration Avancée"


func _on_random_seed_toggled(pressed: bool) -> void:
	seed_input.editable = not pressed
	if pressed:
		GameSettingsAutoload.randomize_seed()
		seed_input.text = str(GameSettingsAutoload.seed)


func _on_octave_changed(value: float) -> void:
	octave_label.text = str(int(value))

func _on_biome_size_changed(value: float) -> void:
	biome_size_label.text = str(int(value))

func _on_render_distance_changed(value: float) -> void:
	render_distance_label.text = str(int(value))

func _on_blend_radius_changed(value: float) -> void:
	blend_radius_label.text = str(int(value))

func _on_chunk_size_changed(value: float) -> void:
	chunk_size_label.text = str(int(value))

func _on_vertex_spacing_changed(value: float) -> void:
	vertex_spacing_label.text = str(value)

func _on_worker_threads_changed(value: float) -> void:
	worker_threads_label.text = str(int(value))


func _on_play_pressed() -> void:
	var temp_seed := seed_input.text.strip_edges()
	if not random_seed_check.button_pressed:
		if temp_seed.is_valid_int():
			GameSettingsAutoload.seed = int(temp_seed)
		else:
			push_warning("Invalid seed: '%s' -> using default" % temp_seed)
			GameSettingsAutoload.seed = GameSettings.DEFAULT_SEED

	GameSettingsAutoload.octave = int(octave_slider.value)
	GameSettingsAutoload.biome_size = int(biome_size_slider.value)
	GameSettingsAutoload.render_distance = int(render_distance_slider.value)
	GameSettingsAutoload.biome_blending = biome_blending_check.button_pressed
	GameSettingsAutoload.blend_radius = blend_radius_slider.value
	GameSettingsAutoload.chunk_size = int(chunk_size_slider.value)
	GameSettingsAutoload.vertex_spacing = vertex_spacing_slider.value
	GameSettingsAutoload.max_worker_threads = int(worker_threads_slider.value)

	var error := get_tree().change_scene_to_file("res://scenes/main/gui_loading_world.tscn")
	if error != OK:
		push_error("Failed to load loading screen (error=%s)" % error)


func _on_cancel_pressed() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/main/gui_main_menu.tscn")
	if error != OK:
		push_error("Failed to load main_menu (error=%s)" % error)
