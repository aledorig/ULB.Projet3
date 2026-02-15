class_name ChunkMeshBuilder
extends RefCounted

const OVERLAP: int = 1
const LOD_DIVISORS: Array[int] = [1, 2, 4]
const SKIRT_DROP: float = 10.0

var chunk_size:     int
var vertex_spacing: float
var terrain_gen:    TerrainGenerator

var effective_chunk_size: int
var effective_spacing:    float
var lod_level:            int

# Index buffer computed once per effective size and shared
static var _index_cache: Dictionary = {}

static func _get_or_build_index_buffer(p_chunk_size: int, p_overlap: int) -> PackedInt32Array:
	if _index_cache.has(p_chunk_size):
		return _index_cache[p_chunk_size]

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

	_index_cache[p_chunk_size] = indices
	return indices

func _init(p_chunk_size: int, p_vertex_spacing: float, p_terrain_gen: TerrainGenerator, p_lod: int = 0) -> void:
	chunk_size = p_chunk_size
	vertex_spacing = p_vertex_spacing
	terrain_gen = p_terrain_gen
	lod_level = clampi(p_lod, 0, LOD_DIVISORS.size() - 1)

	var divisor: int = LOD_DIVISORS[lod_level]
	@warning_ignore("integer_division")
	effective_chunk_size = (p_chunk_size - 1) / divisor + 1
	effective_spacing = p_vertex_spacing * divisor

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
	var mesh: ArrayMesh
	if lod_level > 0:
		mesh = _build_mesh_with_skirts(vertices, colors, normals)
	else:
		mesh = _build_mesh_direct(vertices, colors, normals)
	var build_time := (Time.get_ticks_usec() - t3) / 1000.0

	var total_time := (Time.get_ticks_usec() - t0) / 1000.0

	if total_time > 20:
		print("[MESH] chunk %v LOD%d: vertex=%.1f norm=%.1f build=%.1f TOTAL=%.1f ms" % [
			chunk_position, lod_level, vertex_time, normal_time, build_time, total_time
		])

	return mesh

func _generate_vertex_data(chunk_position: Vector2) -> Dictionary:
	var extended_size: int = effective_chunk_size + 2 * OVERLAP
	var total_verts: int = extended_size * extended_size

	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	vertices.resize(total_verts)
	colors.resize(total_verts)

	# Origin uses original chunk_size for consistent world footprint
	var chunk_world_size: float = (chunk_size - 1) * vertex_spacing
	var origin_x: float = chunk_position.x * chunk_world_size - OVERLAP * effective_spacing
	var origin_z: float = chunk_position.y * chunk_world_size - OVERLAP * effective_spacing

	terrain_gen.get_vertex_data_batch(
		origin_x, origin_z,
		extended_size, extended_size,
		effective_spacing,
		vertices, colors
	)

	return {
		"vertices": vertices,
		"colors": colors
	}

func _calculate_normals_from_heights(vertices: PackedVector3Array) -> PackedVector3Array:
	var extended_size: int = effective_chunk_size + 2 * OVERLAP
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

			var dx: float = (h_left - h_right) / (2.0 * effective_spacing)
			var dz: float = (h_up - h_down) / (2.0 * effective_spacing)

			normals[idx] = Vector3(dx, 1.0, dz).normalized()

	return normals


func _build_mesh_direct(vertices: PackedVector3Array, colors: PackedColorArray, normals: PackedVector3Array) -> ArrayMesh:
	var indices: PackedInt32Array = _get_or_build_index_buffer(effective_chunk_size, OVERLAP)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR]  = colors
	arrays[Mesh.ARRAY_INDEX]  = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_mesh_with_skirts(vertices: PackedVector3Array, colors: PackedColorArray, normals: PackedVector3Array) -> ArrayMesh:
	var extended_size: int = effective_chunk_size + 2 * OVERLAP
	var base_indices: PackedInt32Array = _get_or_build_index_buffer(effective_chunk_size, OVERLAP)

	# Collect edge vertices of the visible grid (not the overlap)
	var edge_verts: Array[int] = []
	var start: int = OVERLAP
	var end_idx: int = OVERLAP + effective_chunk_size - 1

	# Top edge (z = start)
	for x in range(start, end_idx + 1):
		edge_verts.append(start * extended_size + x)
	# Bottom edge (z = end_idx)
	for x in range(start, end_idx + 1):
		edge_verts.append(end_idx * extended_size + x)
	# Left edge (x = start), skip corners already added
	for z in range(start + 1, end_idx):
		edge_verts.append(z * extended_size + start)
	# Right edge (x = end_idx), skip corners
	for z in range(start + 1, end_idx):
		edge_verts.append(z * extended_size + end_idx)

	# Build extended arrays: original verts + skirt duplicates lowered
	var skirt_base: int = vertices.size()
	var skirt_count: int = edge_verts.size()

	var ext_vertices := vertices.duplicate()
	var ext_normals := normals.duplicate()
	var ext_colors := colors.duplicate()

	ext_vertices.resize(skirt_base + skirt_count)
	ext_normals.resize(skirt_base + skirt_count)
	ext_colors.resize(skirt_base + skirt_count)

	for i in range(skirt_count):
		var orig_idx: int = edge_verts[i]
		var v: Vector3 = vertices[orig_idx]
		ext_vertices[skirt_base + i] = Vector3(v.x, v.y - SKIRT_DROP, v.z)
		ext_normals[skirt_base + i] = normals[orig_idx]
		ext_colors[skirt_base + i] = colors[orig_idx]

	# Build skirt triangle strips for each edge
	var skirt_indices := PackedInt32Array()
	var top_count: int = effective_chunk_size
	var bot_offset: int = top_count
	var left_offset: int = top_count * 2
	var left_count: int = effective_chunk_size - 2
	var right_offset: int = left_offset + left_count

	# Top edge strip
	for i in range(top_count - 1):
		var a: int = edge_verts[i]
		var b: int = edge_verts[i + 1]
		var sa: int = skirt_base + i
		var sb: int = skirt_base + i + 1
		skirt_indices.append(a)
		skirt_indices.append(sa)
		skirt_indices.append(b)
		skirt_indices.append(b)
		skirt_indices.append(sa)
		skirt_indices.append(sb)

	# Bottom edge strip
	for i in range(top_count - 1):
		var a: int = edge_verts[bot_offset + i]
		var b: int = edge_verts[bot_offset + i + 1]
		var sa: int = skirt_base + bot_offset + i
		var sb: int = skirt_base + bot_offset + i + 1
		skirt_indices.append(a)
		skirt_indices.append(b)
		skirt_indices.append(sa)
		skirt_indices.append(b)
		skirt_indices.append(sb)
		skirt_indices.append(sa)

	# Left edge strip
	for i in range(left_count - 1):
		var a: int = edge_verts[left_offset + i]
		var b: int = edge_verts[left_offset + i + 1]
		var sa: int = skirt_base + left_offset + i
		var sb: int = skirt_base + left_offset + i + 1
		skirt_indices.append(a)
		skirt_indices.append(b)
		skirt_indices.append(sa)
		skirt_indices.append(b)
		skirt_indices.append(sb)
		skirt_indices.append(sa)

	# Right edge strip
	for i in range(left_count - 1):
		var a: int = edge_verts[right_offset + i]
		var b: int = edge_verts[right_offset + i + 1]
		var sa: int = skirt_base + right_offset + i
		var sb: int = skirt_base + right_offset + i + 1
		skirt_indices.append(a)
		skirt_indices.append(sa)
		skirt_indices.append(b)
		skirt_indices.append(b)
		skirt_indices.append(sa)
		skirt_indices.append(sb)

	# Combine base + skirt indices
	var combined_indices := base_indices.duplicate()
	combined_indices.append_array(skirt_indices)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = ext_vertices
	arrays[Mesh.ARRAY_NORMAL] = ext_normals
	arrays[Mesh.ARRAY_COLOR]  = ext_colors
	arrays[Mesh.ARRAY_INDEX]  = combined_indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
