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
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Step 1: Generate all vertices and colors (with overlap)
	var vertex_data: Dictionary = _generate_vertex_data(chunk_position)
	var vertices: Array = vertex_data.vertices
	var colors: Array = vertex_data.colors
	
	# Step 2: Create triangles with extended geometry
	_create_triangles(surface_tool, vertices, colors)
	
	# Step 3: Generate normals and extract them
	var vertex_normals: Dictionary = _generate_and_extract_normals(surface_tool)
	
	# Step 4: Build final mesh with only inner vertices
	return _build_final_mesh(vertices, colors, vertex_normals)

# ============================================================================
# VERTEX GENERATION
# ============================================================================

func _generate_vertex_data(chunk_position: Vector2) -> Dictionary:
	var extended_size: int = chunk_size + 2 * OVERLAP
	var vertices: Array[Vector3] = []
	var colors: Array[Color] = []
	
	for z in range(extended_size):
		for x in range(extended_size):
			var local_x: int = x - OVERLAP
			var local_z: int = z - OVERLAP
			
			var world_x: float = (chunk_position.x * (chunk_size - 1) + local_x) * vertex_spacing
			var world_z: float = (chunk_position.y * (chunk_size - 1) + local_z) * vertex_spacing
			
			var height: float = terrain_gen.get_height(world_x, world_z)
			var vertex_color: Color = terrain_gen.get_surface_color(world_x, world_z, height)
			
			vertices.append(Vector3(local_x * vertex_spacing, height, local_z * vertex_spacing))
			colors.append(vertex_color)
	
	return {
		"vertices": vertices,
		"colors": colors
	}

# ============================================================================
# TRIANGLE CREATION
# ============================================================================

func _create_triangles(surface_tool: SurfaceTool, vertices: Array, colors: Array) -> void:
	var extended_size: int = chunk_size + 2 * OVERLAP
	
	for z in range(extended_size - 1):
		for x in range(extended_size - 1):
			var top_left: int = z * extended_size + x
			var top_right: int = top_left + 1
			var bottom_left: int = (z + 1) * extended_size + x
			var bottom_right: int = bottom_left + 1
			
			# First triangle
			surface_tool.set_color(colors[top_left])
			surface_tool.add_vertex(vertices[top_left])
			surface_tool.set_color(colors[top_right])
			surface_tool.add_vertex(vertices[top_right])
			surface_tool.set_color(colors[bottom_left])
			surface_tool.add_vertex(vertices[bottom_left])
			
			# Second triangle
			surface_tool.set_color(colors[top_right])
			surface_tool.add_vertex(vertices[top_right])
			surface_tool.set_color(colors[bottom_right])
			surface_tool.add_vertex(vertices[bottom_right])
			surface_tool.set_color(colors[bottom_left])
			surface_tool.add_vertex(vertices[bottom_left])

# ============================================================================
# NORMAL GENERATION
# ============================================================================

func _generate_and_extract_normals(surface_tool: SurfaceTool) -> Dictionary:
	surface_tool.generate_normals()
	surface_tool.index()
	var full_mesh: ArrayMesh = surface_tool.commit()
	
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(full_mesh, 0)
	
	var vertex_normals: Dictionary = {}
	for i in range(mdt.get_vertex_count()):
		var vertex_pos: Vector3 = mdt.get_vertex(i)
		var vertex_normal: Vector3 = mdt.get_vertex_normal(i)
		var key := Vector3(
			round(vertex_pos.x / vertex_spacing),
			0,
			round(vertex_pos.z / vertex_spacing)
		)
		vertex_normals[key] = vertex_normal
	
	return vertex_normals

# ============================================================================
# FINAL MESH ASSEMBLY
# ============================================================================

func _build_final_mesh(vertices: Array, colors: Array, vertex_normals: Dictionary) -> ArrayMesh:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var extended_size: int = chunk_size + 2 * OVERLAP
	
	for z in range(OVERLAP, chunk_size + OVERLAP - 1):
		for x in range(OVERLAP, chunk_size + OVERLAP - 1):
			var idx: int = z * extended_size + x
			
			var top_left: Vector3 = vertices[idx]
			var top_right: Vector3 = vertices[idx + 1]
			var bottom_left: Vector3 = vertices[idx + extended_size]
			var bottom_right: Vector3 = vertices[idx + extended_size + 1]
			
			var c_tl: Color = colors[idx]
			var c_tr: Color = colors[idx + 1]
			var c_bl: Color = colors[idx + extended_size]
			var c_br: Color = colors[idx + extended_size + 1]
			
			var n_tl: Vector3 = _get_normal(top_left, vertex_normals)
			var n_tr: Vector3 = _get_normal(top_right, vertex_normals)
			var n_bl: Vector3 = _get_normal(bottom_left, vertex_normals)
			var n_br: Vector3 = _get_normal(bottom_right, vertex_normals)
			
			# First triangle
			surface_tool.set_normal(n_tl)
			surface_tool.set_color(c_tl)
			surface_tool.add_vertex(top_left)
			surface_tool.set_normal(n_tr)
			surface_tool.set_color(c_tr)
			surface_tool.add_vertex(top_right)
			surface_tool.set_normal(n_bl)
			surface_tool.set_color(c_bl)
			surface_tool.add_vertex(bottom_left)
			
			# Second triangle
			surface_tool.set_normal(n_tr)
			surface_tool.set_color(c_tr)
			surface_tool.add_vertex(top_right)
			surface_tool.set_normal(n_br)
			surface_tool.set_color(c_br)
			surface_tool.add_vertex(bottom_right)
			surface_tool.set_normal(n_bl)
			surface_tool.set_color(c_bl)
			surface_tool.add_vertex(bottom_left)
	
	surface_tool.index()
	return surface_tool.commit()

# ============================================================================
# UTILITY
# ============================================================================

func _get_normal(vertex: Vector3, normals: Dictionary) -> Vector3:
	var key := Vector3(
		round(vertex.x / vertex_spacing),
		0,
		round(vertex.z / vertex_spacing)
	)
	return normals.get(key, Vector3.UP)
