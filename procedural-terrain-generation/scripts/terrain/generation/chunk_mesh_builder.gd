class_name ChunkMeshBuilder
extends RefCounted

# Overlap for seamless normals
const OVERLAP: int = 1

var chunk_size:     int
var vertex_spacing: float
var terrain_gen:    TerrainGenerator

func _init(p_chunk_size: int, p_vertex_spacing: float, p_terrain_gen: TerrainGenerator):
	chunk_size = p_chunk_size
	vertex_spacing = p_vertex_spacing
	terrain_gen = p_terrain_gen

func build_chunk_mesh(chunk_position: Vector2) -> ArrayMesh:
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Step 1: Generate all vertices and colors
	var vertex_data = _generate_vertex_data(chunk_position)
	var vertices = vertex_data.vertices
	var colors = vertex_data.colors
	
	# Step 2: Create triangles with extended geometry
	_create_triangles(surface_tool, vertices, colors)
	
	# Step 3: Generate normals and extract them
	var vertex_normals = _generate_and_extract_normals(surface_tool)
	
	# Step 4: Build final mesh with only inner vertices and colors
	return _build_final_mesh(vertices, colors, vertex_normals)

func _generate_vertex_data(chunk_position: Vector2) -> Dictionary:
	var extended_size = chunk_size + 2 * OVERLAP
	var vertices = []
	var colors = []
	
	for z in range(extended_size):
		for x in range(extended_size):
			var local_x = x - OVERLAP
			var local_z = z - OVERLAP
			
			var world_x = (chunk_position.x * (chunk_size - 1) + local_x) * vertex_spacing
			var world_z = (chunk_position.y * (chunk_size - 1) + local_z) * vertex_spacing
			
			# Get height
			var height = terrain_gen.get_height(world_x, world_z)
			
			# Get color with underwater handling
			var vertex_color = terrain_gen.get_surface_color(world_x, world_z, height)
			
			vertices.append(Vector3(local_x * vertex_spacing, height, local_z * vertex_spacing))
			colors.append(vertex_color)
	
	return {
		"vertices": vertices,
		"colors": colors
	}

func _create_triangles(surface_tool: SurfaceTool, vertices: Array, colors: Array) -> void:
	var extended_size = chunk_size + 2 * OVERLAP
	
	for z in range(extended_size - 1):
		for x in range(extended_size - 1):
			var top_left = z * extended_size + x
			var top_right = top_left + 1
			var bottom_left = (z + 1) * extended_size + x
			var bottom_right = bottom_left + 1
			
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

func _generate_and_extract_normals(surface_tool: SurfaceTool) -> Dictionary:
	surface_tool.generate_normals()
	surface_tool.index()
	var full_mesh = surface_tool.commit()
	
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(full_mesh, 0)
	
	var vertex_normals = {}
	for i in range(mdt.get_vertex_count()):
		var vertex_pos = mdt.get_vertex(i)
		var vertex_normal = mdt.get_vertex_normal(i)
		var key = Vector3(round(vertex_pos.x / vertex_spacing), 0, round(vertex_pos.z / vertex_spacing))
		vertex_normals[key] = vertex_normal
	
	return vertex_normals

func _build_final_mesh(vertices: Array, colors: Array, vertex_normals: Dictionary) -> ArrayMesh:
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var extended_size = chunk_size + 2 * OVERLAP
	
	for z in range(OVERLAP, chunk_size + OVERLAP - 1):
		for x in range(OVERLAP, chunk_size + OVERLAP - 1):
			var idx = z * extended_size + x
			
			var top_left = vertices[idx]
			var top_right = vertices[idx + 1]
			var bottom_left = vertices[idx + extended_size]
			var bottom_right = vertices[idx + extended_size + 1]
			
			var c_tl = colors[idx]
			var c_tr = colors[idx + 1]
			var c_bl = colors[idx + extended_size]
			var c_br = colors[idx + extended_size + 1]
			
			# Get normals from lookup
			var n_tl = _get_normal(top_left, vertex_normals)
			var n_tr = _get_normal(top_right, vertex_normals)
			var n_bl = _get_normal(bottom_left, vertex_normals)
			var n_br = _get_normal(bottom_right, vertex_normals)
			
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

func _get_normal(vertex: Vector3, normals: Dictionary) -> Vector3:
	var key = Vector3(round(vertex.x / vertex_spacing), 0, round(vertex.z / vertex_spacing))
	return normals.get(key, Vector3.UP)
