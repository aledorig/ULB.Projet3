extends TextureRect

const MIN_NORMALIZE_EPS := 0.000001
const MIN_VECTOR_EPS := 0.0005
const MIN_LINE_EPS := 0.001

@export var vector_image_size: int = 500
@export var grid_cell_px: int = 32
@export var grid_line_thickness: int = 2
@export var arrow_len_px: float = 16.0
@export var arrow_strength: float = 1.0
@export var arrows_show_descent: bool = false

@export var preview_freq_mult: float = 100.0
@export var lacunarity: float = 3.0
@export var persistence: float = 0.5
@export var use_abs_ridges: bool = false
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
	var value_range := maxf(range_info.max_value - range_info.min_value, MIN_NORMALIZE_EPS)

	var size := clampi(vector_image_size, 128, 2048)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)

	var cell := maxi(grid_cell_px, 4)
	var thickness := maxi(grid_line_thickness, 1)

	_draw_grid_bw(img, size, size, cell, thickness)
	_draw_arrows(
		img, grid, width, height, value_range, cell, arrow_len_px, arrow_strength
	)

	texture = ImageTexture.create_from_image(img)


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


func _draw_grid_bw(img: Image, width: int, height: int, cell: int, thickness: int) -> void:
	var black := Color.BLACK

	for x in range(0, width, cell):
		for t in range(thickness):
			var xx := x + t
			if xx >= width:
				break
			for y in range(height):
				img.set_pixel(xx, y, black)

	for y in range(0, height, cell):
		for t in range(thickness):
			var yy := y + t
			if yy >= height:
				break
			for x in range(width):
				img.set_pixel(x, yy, black)


func _draw_arrows(
	img: Image,
	grid: PackedFloat32Array,
	grid_width: int,
	grid_height: int,
	value_range: float,
	cell_px: int,
	arrow_len: float,
	strength: float
) -> void:
	var black := Color.BLACK
	var img_w := img.get_width()
	var img_h := img.get_height()

	for py in range(0, img_h + 1, cell_px):
		for px in range(0, img_w + 1, cell_px):
			var sample := _compute_gradient_vector(grid, grid_width, grid_height, value_range, px, py, img_w, img_h) * strength

			if sample.length() < MIN_VECTOR_EPS:
				continue

			var dir := sample.normalized()

			if arrows_show_descent:
				dir = -dir

			var from := Vector2(px, py)
			var to := from + dir * arrow_len
			_draw_arrow_bw(img, from, to, black)


func _compute_gradient_vector(
	grid: PackedFloat32Array,
	grid_width: int,
	grid_height: int,
	value_range: float,
	px: int,
	py: int,
	img_w: int,
	img_h: int
) -> Vector2:
	var gx_f := (float(px) / float(max(img_w - 1, 1))) * float(grid_width - 1)
	var gy_f := (float(py) / float(max(img_h - 1, 1))) * float(grid_height - 1)

	var gx := clampi(int(round(gx_f)), 1, grid_width - 2)
	var gy := clampi(int(round(gy_f)), 1, grid_height - 2)

	var dx := (_grid_at(grid, grid_width, gx + 1, gy) - _grid_at(grid, grid_width, gx - 1, gy)) * 0.5
	var dy := (_grid_at(grid, grid_width, gx, gy + 1) - _grid_at(grid, grid_width, gx, gy - 1)) * 0.5

	dx /= maxf(value_range, MIN_NORMALIZE_EPS)
	dy /= maxf(value_range, MIN_NORMALIZE_EPS)

	return Vector2(dx, dy)


func _grid_at(grid: PackedFloat32Array, width: int, x: int, y: int) -> float:
	return grid[y * width + x]


func _draw_arrow_bw(img: Image, from: Vector2, to: Vector2, color: Color) -> void:
	_draw_line_bw(img, from, to, color)

	var delta := to - from
	if delta.length() < MIN_LINE_EPS:
		return

	var dir := delta.normalized()
	var perp := Vector2(-dir.y, dir.x)

	var head_len := maxf(3.0, arrow_len_px * 0.35)
	var head_width := maxf(2.0, arrow_len_px * 0.22)

	var a := to - dir * head_len + perp * head_width
	var b := to - dir * head_len - perp * head_width

	_draw_line_bw(img, to, a, color)
	_draw_line_bw(img, to, b, color)


func _draw_line_bw(img: Image, from: Vector2, to: Vector2, color: Color) -> void:
	var x0 := int(round(from.x))
	var y0 := int(round(from.y))
	var x1 := int(round(to.x))
	var y1 := int(round(to.y))

	var dx := x1 - x0
	var dy := y1 - y0
	var steps := maxi(abs(dx), abs(dy))

	if steps == 0:
		if x0 >= 0 and x0 < img.get_width() and y0 >= 0 and y0 < img.get_height():
			img.set_pixel(x0, y0, color)
		return

	var fx := float(dx) / float(steps)
	var fy := float(dy) / float(steps)
	var x := float(x0)
	var y := float(y0)

	for _i in range(steps + 1):
		var xi := int(round(x))
		var yi := int(round(y))

		if xi >= 0 and xi < img.get_width() and yi >= 0 and yi < img.get_height():
			img.set_pixel(xi, yi, color)

		x += fx
		y += fy
