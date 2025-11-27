class_name ChunkMeshBuilder
extends RefCounted

## Builds terrain mesh for a single chunk with proper normal calculation

# ============================================================================
# CONSTANTS
# ============================================================================

## Overlap vertices for seamless normals at chunk boundaries
const OVERLAP: int = 1

# ============================================================================
# CONFIGURATION
# ============================================================================

var chunk_size:     int
var vertex_spacing: float
var terrain_gen:    TerrainGenerator

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_chunk_size: int, p_vertex_spacing: float, p_terrain_gen: TerrainGenerator) -> void:
	chunk_size = p_chunk_size
	vertex_spacing = p_vertex_spacing
	terrain_gen = p_terrain_gen

# ============================================================================
# MESH BUILDING
# ============================================================================

func build_chunk_mesh(chunk_position: Vector2) -> ArrayMesh:
	var t0 := Time.get_ticks_usec()

	# Step 1: Generate all vertices and colors (with overlap for normals)
	var t1 := Time.get_ticks_usec()
	var vertex_data: Dictionary = _generate_vertex_data(chunk_position)
	var vertices: PackedVector3Array = vertex_data.vertices
	var colors: PackedColorArray = vertex_data.colors
	var vertex_time := (Time.get_ticks_usec() - t1) / 1000.0

	# Step 2: Calculate normals directly from heightmap (fast!)
	var t2 := Time.get_ticks_usec()
	var normals: PackedVector3Array = _calculate_normals_from_heights(vertices)
	var normal_time := (Time.get_ticks_usec() - t2) / 1000.0

	# Step 3: Build final mesh directly
	var t3 := Time.get_ticks_usec()
	var mesh := _build_mesh_direct(vertices, colors, normals)
	var build_time := (Time.get_ticks_usec() - t3) / 1000.0

	var total_time := (Time.get_ticks_usec() - t0) / 1000.0

	# Log breakdown (lowered threshold to see improvement)
	if total_time > 20:
		print("[MESH] chunk %v: vertex=%.1f norm=%.1f build=%.1f TOTAL=%.1f ms" % [
			chunk_position, vertex_time, normal_time, build_time, total_time
		])

	return mesh

# ============================================================================
# VERTEX GENERATION
# ============================================================================

func _generate_vertex_data(chunk_position: Vector2) -> Dictionary:
	var extended_size: int = chunk_size + 2 * OVERLAP
	var total_verts: int = extended_size * extended_size

	# Use packed arrays for better performance (less GC pressure, contiguous memory)
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	vertices.resize(total_verts)
	colors.resize(total_verts)

	# Calculate world origin for this chunk
	var origin_x: float = (chunk_position.x * (chunk_size - 1) - OVERLAP) * vertex_spacing
	var origin_z: float = (chunk_position.y * (chunk_size - 1) - OVERLAP) * vertex_spacing

	# Batch generate all vertex data at once
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

# ============================================================================
# NORMAL CALCULATION (direct from heightmap - much faster!)
# ============================================================================

func _calculate_normals_from_heights(vertices: PackedVector3Array) -> PackedVector3Array:
	var extended_size: int = chunk_size + 2 * OVERLAP
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(vertices.size())

	for z in range(extended_size):
		for x in range(extended_size):
			var idx: int = z * extended_size + x

			# Get heights of neighbors (with boundary clamping)
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

			# Calculate normal from height differences
			var dx: float = (h_left - h_right) / (2.0 * vertex_spacing)
			var dz: float = (h_up - h_down) / (2.0 * vertex_spacing)

			normals[idx] = Vector3(dx, 1.0, dz).normalized()

	return normals


# ============================================================================
# MESH BUILDING (single pass, no intermediate mesh)
# ============================================================================

func _build_mesh_direct(vertices: PackedVector3Array, colors: PackedColorArray, normals: PackedVector3Array) -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var extended_size: int = chunk_size + 2 * OVERLAP

	# Only iterate over inner vertices (skip overlap border)
	for z in range(OVERLAP, chunk_size + OVERLAP - 1):
		for x in range(OVERLAP, chunk_size + OVERLAP - 1):
			var idx: int = z * extended_size + x

			# Get the 4 corners of this quad
			var tl_idx: int = idx
			var tr_idx: int = idx + 1
			var bl_idx: int = idx + extended_size
			var br_idx: int = idx + extended_size + 1

			# First triangle (top-left, top-right, bottom-left)
			surface_tool.set_normal(normals[tl_idx])
			surface_tool.set_color(colors[tl_idx])
			surface_tool.add_vertex(vertices[tl_idx])

			surface_tool.set_normal(normals[tr_idx])
			surface_tool.set_color(colors[tr_idx])
			surface_tool.add_vertex(vertices[tr_idx])

			surface_tool.set_normal(normals[bl_idx])
			surface_tool.set_color(colors[bl_idx])
			surface_tool.add_vertex(vertices[bl_idx])

			# Second triangle (top-right, bottom-right, bottom-left)
			surface_tool.set_normal(normals[tr_idx])
			surface_tool.set_color(colors[tr_idx])
			surface_tool.add_vertex(vertices[tr_idx])

			surface_tool.set_normal(normals[br_idx])
			surface_tool.set_color(colors[br_idx])
			surface_tool.add_vertex(vertices[br_idx])

			surface_tool.set_normal(normals[bl_idx])
			surface_tool.set_color(colors[bl_idx])
			surface_tool.add_vertex(vertices[bl_idx])

	surface_tool.index()
	return surface_tool.commit()
