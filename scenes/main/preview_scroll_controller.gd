# whouldn't be attached to "preview", but meow
extends TextureRect

const MIN_NORMALIZE_EPS := 0.000001

@export var preview_freq_mult: float = 100.0
@export var lacunarity: float = 3.0
@export var persistence: float = 0.5
@export var contrast: float = 1.4
@export var use_abs_ridges: bool = false
@export var normalize_per_frame: bool = true
@export var max_octaves_preview: int = -1

var chunk_size: int
var vertex_spacing: float
var chunk_pos: Vector2i
var preview_chunks: int


func configure(p_chunk_size: int, p_vertex_spacing: float, p_chunk_pos: Vector2i, p_preview_chunks: int) -> void:
	chunk_size = p_chunk_size
	vertex_spacing = p_vertex_spacing
	chunk_pos = p_chunk_pos
	preview_chunks = p_preview_chunks


func render_preview(gen: TerrainGenerator) -> void:
	var width := chunk_size * preview_chunks
	var height := chunk_size * preview_chunks
	var total := width * height

	var origin := _get_chunk_world_origin()
	var grid := PackedFloat32Array()
	grid.resize(total)

	_fill_grid_height_fbm(gen, grid, origin.x, origin.y, width, height, vertex_spacing)

	var range_info := _compute_min_max(grid)
	var image := _build_height_image(grid, width, height, range_info.min_value, range_info.max_value)
	texture = ImageTexture.create_from_image(image)


func _get_chunk_world_origin() -> Vector2:
	var chunk_world_size := float((chunk_size - 1) * vertex_spacing)
	return Vector2(
		float(chunk_pos.x) * chunk_world_size,
		float(chunk_pos.y) * chunk_world_size
	)


func _compute_min_max(values: PackedFloat32Array) -> Dictionary:
	var min_value := INF
	var max_value := -INF

	for v in values:
		min_value = min(min_value, v)
		max_value = max(max_value, v)

	return {
		"min_value": min_value,
		"max_value": max_value
	}


func _build_height_image(
	grid: PackedFloat32Array,
	width: int,
	height: int,
	min_value: float,
	max_value: float
) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var value_range := maxf(max_value - min_value, MIN_NORMALIZE_EPS)

	var i := 0
	for y in range(height):
		for x in range(width):
			var value := grid[i]
			var normalized := _normalize_height_value(value, min_value, value_range)
			img.set_pixel(x, y, Color(normalized, normalized, normalized, 1.0))
			i += 1

	return img


func _normalize_height_value(value: float, min_value: float, value_range: float) -> float:
	var n01: float

	if normalize_per_frame:
		n01 = (value - min_value) / value_range
	else:
		n01 = clampf(value * 0.5 + 0.5, 0.0, 1.0)

	return pow(n01, 1.0 / maxf(contrast, 0.0001))


func _fill_grid_height_fbm(
	gen: TerrainGenerator,
	out_grid: PackedFloat32Array,
	origin_x: float,
	origin_z: float,
	width: int,
	height: int,
	sample_spacing: float
) -> void:
	var base_scale := TerrainConfig.HEIGHT_FREQ * preview_freq_mult
	var perlins = gen.height_noise.generators

	var total_octaves := perlins.size()
	var used_octaves := total_octaves if max_octaves_preview < 0 else mini(max_octaves_preview, total_octaves)

	var index := 0
	for gz in range(height):
		var world_z := origin_z + float(gz) * sample_spacing

		for gx in range(width):
			var world_x := origin_x + float(gx) * sample_spacing
			out_grid[index] = _sample_fbm_height(perlins, used_octaves, world_x, world_z, base_scale)
			index += 1


func _sample_fbm_height(perlins, used_octaves: int, world_x: float, world_z: float, base_scale: float) -> float:
	var freq := 1.0
	var amp := 1.0
	var sum := 0.0
	var norm := 0.0

	for j in range(used_octaves):
		var n: float = perlins[j].get_value(world_x * base_scale * freq, world_z * base_scale * freq)

		if use_abs_ridges:
			n = 1.0 - absf(n)

		sum += n * amp
		norm += amp
		freq *= lacunarity
		amp *= persistence

	return sum / maxf(norm, MIN_NORMALIZE_EPS)
