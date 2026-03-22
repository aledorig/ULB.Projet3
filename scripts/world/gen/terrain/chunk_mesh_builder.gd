class_name ChunkMeshBuilder
extends RefCounted

const OVERLAP: int = 1

const STEP_COUNT: int = 7
const STEP_FINAL: int = 6
const STEP_NAMES: Array[String] = [
	"Continental Base",
	"+ Shaped Noise",
	"+ Depth Modulation",
	"+ Surface Detail",
	"+ Roughness",
	"Climate Colors",
	"Full Render",
]

var chunk_size: int
var vertex_spacing: float
var terrain_gen: TerrainGenerator
var mesh_size: int
var lod_spacing: float
var max_octaves: int
var height_freq: float

# Index buffer computed once per mesh size and shared
static var _index_cache: Dictionary = { }


static func get_or_build_index_buffer(p_mesh_size: int, p_overlap: int) -> PackedInt32Array:
	if _index_cache.has(p_mesh_size):
		return _index_cache[p_mesh_size]

	var extended_size: int = p_mesh_size + 2 * p_overlap
	var num_quads: int = (p_mesh_size - 1) * (p_mesh_size - 1)
	var indices := PackedInt32Array()
	indices.resize(num_quads * 6)

	var write_idx: int = 0
	for z in range(p_overlap, p_mesh_size + p_overlap - 1):
		for x in range(p_overlap, p_mesh_size + p_overlap - 1):
			var tl: int = z * extended_size + x
			var top_right: int = tl + 1
			var bl: int = tl + extended_size
			var br: int = bl + 1

			indices[write_idx] = tl
			indices[write_idx + 1] = top_right
			indices[write_idx + 2] = bl
			indices[write_idx + 3] = top_right
			indices[write_idx + 4] = br
			indices[write_idx + 5] = bl
			write_idx += 6

	_index_cache[p_mesh_size] = indices
	return indices


func _init(
		p_chunk_size: int,
		p_vertex_spacing: float,
		p_terrain_gen: TerrainGenerator,
		p_mesh_size: int = -1,
		p_max_octaves: int = -1,
		p_height_freq: float = TerrainConfig.HEIGHT_FREQ,
) -> void:
	chunk_size = p_chunk_size
	vertex_spacing = p_vertex_spacing
	terrain_gen = p_terrain_gen
	mesh_size = p_mesh_size if p_mesh_size > 0 else p_chunk_size
	max_octaves = p_max_octaves
	height_freq = p_height_freq

	var chunk_world_size: float = (chunk_size - 1) * vertex_spacing
	lod_spacing = chunk_world_size / (mesh_size - 1) if mesh_size > 1 else vertex_spacing


func build_chunk_mesh(chunk_position: Vector2) -> ArrayMesh:
	var vertex_data: Dictionary = _generate_vertex_data(chunk_position)
	var vertices: PackedVector3Array = vertex_data.vertices
	var colors: PackedColorArray = vertex_data.colors
	var normals: PackedVector3Array = _calculate_normals_from_heights(vertices)
	return _build_mesh(vertices, colors, normals)


func _generate_vertex_data(chunk_position: Vector2) -> Dictionary:
	var extended_size: int = mesh_size + 2 * OVERLAP
	var total_verts: int = extended_size * extended_size

	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	vertices.resize(total_verts)
	colors.resize(total_verts)

	var chunk_world_size: float = (chunk_size - 1) * vertex_spacing
	var origin_x: float = chunk_position.x * chunk_world_size - OVERLAP * lod_spacing
	var origin_z: float = chunk_position.y * chunk_world_size - OVERLAP * lod_spacing

	terrain_gen.get_vertex_data_batch(
		origin_x,
		origin_z,
		extended_size,
		extended_size,
		lod_spacing,
		vertices,
		colors,
		max_octaves,
		height_freq,
	)

	# Offset vertices so first rendered vertex is at local (0,0)
	# Without this, different LOD levels have different overlap offsets,
	# causing gaps between adjacent chunks at different LODs
	var ox: float = OVERLAP * lod_spacing
	for i in range(total_verts):
		vertices[i].x -= ox
		vertices[i].z -= ox

	return {
		"vertices": vertices,
		"colors": colors,
	}


func _calculate_normals_from_heights(vertices: PackedVector3Array) -> PackedVector3Array:
	var extended_size: int = mesh_size + 2 * OVERLAP
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(vertices.size())

	for z in range(extended_size):
		for x in range(extended_size):
			var idx: int = z * extended_size + x

			var h_center: float = vertices[idx].y
			var h_left: float = h_center
			var h_right: float = h_center
			var h_up: float = h_center
			var h_down: float = h_center

			if x > 0:
				h_left = vertices[idx - 1].y
			if x < extended_size - 1:
				h_right = vertices[idx + 1].y
			if z > 0:
				h_up = vertices[idx - extended_size].y
			if z < extended_size - 1:
				h_down = vertices[idx + extended_size].y

			var dx: float = (h_left - h_right) / (2.0 * lod_spacing)
			var dz: float = (h_up - h_down) / (2.0 * lod_spacing)

			normals[idx] = Vector3(dx, 1.0, dz).normalized()

	return normals


func _build_mesh(
		vertices: PackedVector3Array,
		colors: PackedColorArray,
		normals: PackedVector3Array,
) -> ArrayMesh:
	var indices: PackedInt32Array = get_or_build_index_buffer(mesh_size, OVERLAP)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func build_chunk_mesh_all_steps(chunk_position: Vector2) -> Array:
	var extended_size: int = mesh_size + 2 * OVERLAP
	var total_verts: int = extended_size * extended_size

	var chunk_world_size: float = (chunk_size - 1) * vertex_spacing
	var origin_x: float = chunk_position.x * chunk_world_size - OVERLAP * lod_spacing
	var origin_z: float = chunk_position.y * chunk_world_size - OVERLAP * lod_spacing

	var grids: Dictionary = terrain_gen.get_all_grids_batch(
		origin_x,
		origin_z,
		extended_size,
		extended_size,
		lod_spacing,
		max_octaves,
		height_freq,
	)

	var cont_grid: PackedFloat32Array = grids.cont
	var peaks_grid: PackedFloat32Array = grids.peaks
	var noise_grid: PackedFloat32Array = grids.noise
	var depth_grid: PackedFloat32Array = grids.depth
	var surface_grid: PackedFloat32Array = grids.surface
	var roughness_grid: PackedFloat32Array = grids.roughness
	var temp_grid: PackedFloat32Array = grids.temp
	var moist_grid: PackedFloat32Array = grids.moist

	var v0 := PackedVector3Array()
	v0.resize(total_verts)
	var v1 := PackedVector3Array()
	v1.resize(total_verts)
	var v2 := PackedVector3Array()
	v2.resize(total_verts)
	var v3 := PackedVector3Array()
	v3.resize(total_verts)
	var v4 := PackedVector3Array()
	v4.resize(total_verts)

	var c0 := PackedColorArray()
	c0.resize(total_verts)
	var c1 := PackedColorArray()
	c1.resize(total_verts)
	var c2 := PackedColorArray()
	c2.resize(total_verts)
	var c3 := PackedColorArray()
	c3.resize(total_verts)
	var c4 := PackedColorArray()
	c4.resize(total_verts)
	var c5 := PackedColorArray()
	c5.resize(total_verts)

	var ox: float = OVERLAP * lod_spacing
	var h_range: float = TerrainConfig.MAX_AMPLITUDE * 2.0

	for idx in range(total_verts):
		var cont: float = cont_grid[idx]
		var peaks: float = peaks_grid[idx]
		var base: float = terrain_gen.compute_base(cont)
		var amplitude: float = terrain_gen.compute_amplitude(cont, peaks)
		var shaped: float = TerrainGenerator.shape_noise(noise_grid[idx])

		var h1: float = base + shaped * amplitude
		var h2: float = base + shaped * amplitude * (1.0 + depth_grid[idx] * 0.6)
		var h3: float = h2 + surface_grid[idx]
		var alt_factor: float = TerrainGenerator.smoothstep(
			TerrainConfig.ROUGHNESS_ALT_LOW,
			TerrainConfig.ROUGHNESS_ALT_HIGH,
			h3,
		)
		var h4: float = h3 + roughness_grid[idx] * TerrainConfig.ROUGHNESS_AMP * alt_factor

		var lx: float = (idx % extended_size) * lod_spacing - ox
		var lz: float = float(idx / extended_size) * lod_spacing - ox

		v0[idx] = Vector3(lx, base, lz)
		v1[idx] = Vector3(lx, h1, lz)
		v2[idx] = Vector3(lx, h2, lz)
		v3[idx] = Vector3(lx, h3, lz)
		v4[idx] = Vector3(lx, h4, lz)

		c0[idx] = Color.from_hsv(0.0, 0.0, clampf((base - TerrainConfig.OCEAN_BASE) / h_range, 0.0, 1.0))
		c1[idx] = Color.from_hsv(0.0, 0.0, clampf((h1 - TerrainConfig.OCEAN_BASE) / h_range, 0.0, 1.0))
		c2[idx] = Color.from_hsv(0.0, 0.0, clampf((h2 - TerrainConfig.OCEAN_BASE) / h_range, 0.0, 1.0))
		c3[idx] = Color.from_hsv(0.0, 0.0, clampf((h3 - TerrainConfig.OCEAN_BASE) / h_range, 0.0, 1.0))
		c4[idx] = Color.from_hsv(0.0, 0.0, clampf((h4 - TerrainConfig.OCEAN_BASE) / h_range, 0.0, 1.0))

		var temp_01: float = clampf(temp_grid[idx] * 0.5 + 0.5, 0.0, 1.0)
		var moist_01: float = clampf(moist_grid[idx] * 0.5 + 0.5, 0.0, 1.0)
		var cont_01: float = clampf(cont * 0.5 + 0.5, 0.0, 1.0)
		c5[idx] = Color(temp_01, moist_01, cont_01)

	var n0: PackedVector3Array = _calculate_normals_from_heights(v0)
	var n1: PackedVector3Array = _calculate_normals_from_heights(v1)
	var n2: PackedVector3Array = _calculate_normals_from_heights(v2)
	var n3: PackedVector3Array = _calculate_normals_from_heights(v3)
	var n4: PackedVector3Array = _calculate_normals_from_heights(v4)

	return [
		_build_mesh(v0, c0, n0), # 0: Continental Base
		_build_mesh(v1, c1, n1), # 1: + Shaped Noise
		_build_mesh(v2, c2, n2), # 2: + Depth Modulation
		_build_mesh(v3, c3, n3), # 3: + Surface Detail
		_build_mesh(v4, c4, n4), # 4: + Roughness
		_build_mesh(v4, c5, n4), # 5: Climate Colors (flat material)
		_build_mesh(v4, c5, n4), # 6: Full Render (terrain shader)
	]
