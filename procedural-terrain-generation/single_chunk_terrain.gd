extends MeshInstance3D

@export var chunk_size:     int   = 40
@export var vertex_spacing: float = 2.0
@export var height_scale:   float = 10.0
@export var terrain_seed:   int   = 1223334444

var noise: FastNoiseLite
var material_applied: bool = false

func _ready():
	setup_noise()

func setup_noise():
	noise = FastNoiseLite.new()
	noise.seed = terrain_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05

func generate_chunk(chunk_position: Vector2):
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Generate all vertices first
	var vertices = []
	for z in range(chunk_size):
		for x in range(chunk_size):
			var world_x = (chunk_position.x * (chunk_size - 1) + x) * vertex_spacing
			var world_z = (chunk_position.y * (chunk_size - 1) + z) * vertex_spacing
			var height = get_height(world_x, world_z)
			vertices.append(Vector3(x * vertex_spacing, height, z * vertex_spacing))

	# Create triangles with correct winding order
	for z in range(chunk_size - 1):
		for x in range(chunk_size - 1):
			var top_left = z * chunk_size + x
			var top_right = top_left + 1
			var bottom_left = (z + 1) * chunk_size + x
			var bottom_right = bottom_left + 1

			# First triangle
			surface_tool.add_vertex(vertices[top_left])
			surface_tool.add_vertex(vertices[top_right])
			surface_tool.add_vertex(vertices[bottom_left])

			# Second triangle
			surface_tool.add_vertex(vertices[top_right])
			surface_tool.add_vertex(vertices[bottom_right])
			surface_tool.add_vertex(vertices[bottom_left])

	# Generate normals after adding all vertices
	surface_tool.generate_normals()
	mesh = surface_tool.commit()
	
	# Apply material
	if not material_applied:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.2, 0.6, 0.2)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		
		material.metallic = 0.1
		material.roughness = 0.7
		
		material.rim_enabled = true
		material.rim = 0.5
		material.rim_tint = 0.3
		
		mesh.surface_set_material(0, material)
		material_applied = true

# Height function
func get_height(world_x: float, world_z: float) -> float:
	return noise.get_noise_2d(world_x, world_z) * height_scale
