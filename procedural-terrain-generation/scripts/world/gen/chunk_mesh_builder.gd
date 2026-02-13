class_name ChunkMeshBuilder
extends RefCounted

const OVERLAP: int = 1

var chunk_size:     int
var vertex_spacing: float
var terrain_gen:    TerrainGenerator

# Index buffer computed once and shared by all chunks of the same size
static var _cached_indices: PackedInt32Array = PackedInt32Array()
static var _cached_chunk_size: int = -1

static func _get_or_build_index_buffer(p_chunk_size: int, p_overlap: int) -> PackedInt32Array:
	if p_chunk_size == _cached_chunk_size and not _cached_indices.is_empty():
		return _cached_indices

	var extended_size: int = p_chunk_size + 2 * p_overlap
	var num_quads: int = (p_chunk_size - 1) * (p_chunk_size - 1)
	var indices := PackedInt32Array()
	indices.resize(num_quads * 6)

	var write_idx: int = 0
	for z in range(p_overlap, p_chunk_size + p_overlap - 1):
		for x in range(p_overlap, p_chunk_size + p_overlap - 1):
			var tl: int = z * extended_size + x
			var tr: int = tl + 1
			var bl: int = tl + extended_size
			var br: int = bl + 1

			indices[write_idx] = tl
			indices[write_idx + 1] = tr
			indices[write_idx + 2] = bl
			indices[write_idx + 3] = tr
			indices[write_idx + 4] = br
			indices[write_idx + 5] = bl
			write_idx += 6

	_cached_indices = indices
	_cached_chunk_size = p_chunk_size
	return indices

func _init(p_chunk_size: int, p_vertex_spacing: float, p_terrain_gen: TerrainGenerator) -> void:
	chunk_size = p_chunk_size
	vertex_spacing = p_vertex_spacing
	terrain_gen = p_terrain_gen

func build_chunk_mesh(chunk_position: Vector2) -> ArrayMesh:
	var t0 := Time.get_ticks_usec()

	var t1 := Time.get_ticks_usec()
	var vertex_data: Dictionary = _generate_vertex_data(chunk_position)
	var vertices: PackedVector3Array = vertex_data.vertices
	var colors: PackedColorArray = vertex_data.colors
	var vertex_time := (Time.get_ticks_usec() - t1) / 1000.0

	var t2 := Time.get_ticks_usec()
	var normals: PackedVector3Array = _calculate_normals_from_heights(vertices)
	var normal_time := (Time.get_ticks_usec() - t2) / 1000.0

	var t3 := Time.get_ticks_usec()
	var mesh := _build_mesh_direct(vertices, colors, normals)
	var build_time := (Time.get_ticks_usec() - t3) / 1000.0

	var total_time := (Time.get_ticks_usec() - t0) / 1000.0

	if total_time > 20:
		print("[MESH] chunk %v: vertex=%.1f norm=%.1f build=%.1f TOTAL=%.1f ms" % [
			chunk_position, vertex_time, normal_time, build_time, total_time
		])

	return mesh

func _generate_vertex_data(chunk_position: Vector2) -> Dictionary:
	var extended_size: int = chunk_size + 2 * OVERLAP
	var total_verts: int = extended_size * extended_size

	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	vertices.resize(total_verts)
	colors.resize(total_verts)

	var origin_x: float = (chunk_position.x * (chunk_size - 1) - OVERLAP) * vertex_spacing
	var origin_z: float = (chunk_position.y * (chunk_size - 1) - OVERLAP) * vertex_spacing

	terrain_gen.get_vertex_data_batch(
		origin_x, origin_z,
		extended_size, extended_size,
		vertex_spacing,
		vertices, colors
	)

	return {
		"vertices": vertices,
		"colors": colors
	}

func _calculate_normals_from_heights(vertices: PackedVector3Array) -> PackedVector3Array:
	var extended_size: int = chunk_size + 2 * OVERLAP
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

			var dx: float = (h_left - h_right) / (2.0 * vertex_spacing)
			var dz: float = (h_up - h_down) / (2.0 * vertex_spacing)

			normals[idx] = Vector3(dx, 1.0, dz).normalized()

	return normals


func _build_mesh_direct(vertices: PackedVector3Array, colors: PackedColorArray, normals: PackedVector3Array) -> ArrayMesh:
	var indices: PackedInt32Array = _get_or_build_index_buffer(chunk_size, OVERLAP)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR]  = colors
	arrays[Mesh.ARRAY_INDEX]  = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
