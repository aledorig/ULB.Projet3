extends Control

@onready var preview_2d: Node = get_node("MarginContainer/VBoxContainer/Scroll/HBoxContainer/Preview")
@onready var vector_preview: Node = get_node("MarginContainer/VBoxContainer/Scroll/HBoxContainer/VectorPreview")
@onready var preview_3d: Node = get_node("VP3D")
@onready var settings_panel: Node = get_node("SettingsPanel")
@onready var preview_scroll: HSlider = get_node("MarginContainer/VBoxContainer/PreviewScroll")

@export var chunk_size: int = GameSettingsAutoload.chunk_size
@export var vertex_spacing: float = GameSettingsAutoload.vertex_spacing
@export var chunk_pos: Vector2i = Vector2i.ZERO
@export var preview_chunks: int = 1

@export var seed_value: int = GameSettingsAutoload.seed
@export var octaves: int = GameSettingsAutoload.octave

var gen: TerrainGenerator


func _ready() -> void:
	_rebuild_generator()
	_setup_children()
	_connect_signals()
	_render_all()


func _rebuild_generator() -> void:
	gen = TerrainGenerator.new(seed_value, octaves)


func _setup_children() -> void:
	if settings_panel.has_method("set_values"):
		settings_panel.set_values(seed_value, octaves)

	if preview_2d.has_method("configure"):
		preview_2d.configure(chunk_size, vertex_spacing, chunk_pos, preview_chunks)

	if vector_preview.has_method("configure"):
		vector_preview.configure(chunk_size, vertex_spacing, chunk_pos, preview_chunks)

	if preview_3d.has_method("configure"):
		preview_3d.configure(chunk_size, vertex_spacing, chunk_pos)


func _connect_signals() -> void:
	if settings_panel.has_signal("seed_changed"):
		settings_panel.seed_changed.connect(_on_seed_changed)

	if settings_panel.has_signal("octaves_changed"):
		settings_panel.octaves_changed.connect(_on_octaves_changed)

	if preview_scroll.value_changed.is_connected(_on_preview_scroll_value_changed) == false:
		preview_scroll.value_changed.connect(_on_preview_scroll_value_changed)


func _render_all() -> void:
	if preview_2d.has_method("render_preview"):
		preview_2d.render_preview(gen)

	if vector_preview.has_method("render_preview"):
		vector_preview.render_preview(gen)

	if preview_3d.has_method("render_preview"):
		preview_3d.render_preview(gen)


func _on_seed_changed(value: int) -> void:
	seed_value = value
	_rebuild_generator()
	_render_all()


func _on_octaves_changed(value: int) -> void:
	octaves = value
	_rebuild_generator()
	_render_all()


func _on_preview_scroll_value_changed(value: float) -> void:
	var scroll := get_node("MarginContainer/VBoxContainer/Scroll") as ScrollContainer
	scroll.scroll_horizontal = int(value)
