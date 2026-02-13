class_name GuiMinimap
extends Control

@export var display_size:    int   = 200
@export var sample_size:     int   = 50
@export var world_scale:     float = 16.0
@export var update_interval: float = 0.2

@onready var ship: CharacterBody3D = get_node("/root/TerrainWorld/Executioner")
@onready var chunk_manager: ChunkManager = get_node("/root/TerrainWorld")

var biome_manager: BiomeManager = null
var texture_rect:  TextureRect  = null
var image:         Image     = null
var player_marker: ColorRect = null
var update_timer:  float = 0.0

func _ready() -> void:
	if chunk_manager == null:
		push_error("GuiMinimap: Couldn't get ChunkManager node")
		return

	# Children _ready() fires before parent
	# wait for ChunkManager to initialize
	if not chunk_manager.is_node_ready():
		await chunk_manager.ready

	biome_manager = chunk_manager.debug_terrain_generator.biome_manager
	_setup_ui()
	_update_map()


func _setup_ui() -> void:
	custom_minimum_size = Vector2(display_size + 10, display_size + 10)
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -display_size - 20
	offset_right = -10
	offset_top = 10
	offset_bottom = display_size + 20

	var panel: Panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	texture_rect = TextureRect.new()
	texture_rect.position = Vector2(5, 5)
	texture_rect.size = Vector2(display_size, display_size)
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(texture_rect)

	player_marker = ColorRect.new()
	player_marker.color = Color.RED
	player_marker.size = Vector2(6, 6)
	player_marker.position = Vector2(5 + display_size / 2 - 3, 5 + display_size / 2 - 3)
	add_child(player_marker)

	# Small image that gets scaled up by TextureRect
	image = Image.create(sample_size, sample_size, false, Image.FORMAT_RGB8)

func _process(delta: float) -> void:
	update_timer += delta
	if update_timer >= update_interval:
		update_timer = 0.0
		_update_map()


func _update_map() -> void:
	if ship == null or biome_manager == null:
		return

	var center_x: float = ship.global_position.x
	var center_z: float = ship.global_position.z
	var half: int = sample_size / 2

	for py in range(sample_size):
		for px in range(sample_size):
			var world_x: float = center_x + (px - half) * world_scale
			var world_z: float = center_z + (py - half) * world_scale

			var biome: TerrainConstants.Biome = biome_manager.get_biome(world_x, world_z)
			image.set_pixel(px, py, TerrainConstants.BIOME_COLORS[biome])

	texture_rect.texture = ImageTexture.create_from_image(image)
