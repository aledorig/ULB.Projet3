class_name RiverVisualizer
extends Node3D

const CELL_SIZE := 64.0
const CELL_Y_OFFSET := 1.5 # slightly above terrain to avoid z-fighting

var mesh: ImmediateMesh
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D

var coast: ImmediateMesh
var coast_instance: MeshInstance3D
var coast_material: StandardMaterial3D

var flat: ImmediateMesh
var flat_instance: MeshInstance3D
var flat_material: StandardMaterial3D

func _ready() -> void:
	mesh = ImmediateMesh.new()
	coast = ImmediateMesh.new()
	flat = ImmediateMesh.new()
	
	mesh_instance = MeshInstance3D.new()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	
	coast_instance = MeshInstance3D.new()
	coast_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(coast_instance)

	flat_instance = MeshInstance3D.new()
	flat_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flat_instance)

	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.5, 1.0)
	material.no_depth_test = true

	coast_material = StandardMaterial3D.new()
	coast_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	coast_material.albedo_color = Color(0.857, 0.338, 0.194, 1.0)
	coast_material.no_depth_test = true
	coast.surface_set_material(0, coast_material)
	
	flat_material = StandardMaterial3D.new()
	flat_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat_material.no_depth_test = true
	flat_material.albedo_color = Color.WHITE
	flat_material.vertex_color_use_as_albedo = true

func draw_candidates(candidates: Array[Vector3]) -> void:
	mesh.clear_surfaces()

	var cross_size := 10.0
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for point in candidates:
		var p := Vector3(point.x, point.y + 2.0, point.z)
		
		mesh.surface_add_vertex(p + Vector3(-cross_size, 0, 0))
		mesh.surface_add_vertex(p + Vector3(cross_size, 0, 0))
		mesh.surface_add_vertex(p + Vector3(0, 0, -cross_size))
		mesh.surface_add_vertex(p + Vector3(0, 0, cross_size))
		mesh.surface_add_vertex(p + Vector3(0, -cross_size, 0))
		mesh.surface_add_vertex(p + Vector3(0, cross_size, 0))
	mesh.surface_end()

	mesh_instance.mesh = mesh
	print("[RIVER] Drawing %d candidates" % candidates.size())

func _build_square(imesh: ImmediateMesh, center: Vector2, y: float, size: float) -> void:
	var half := size * 0.5

	var bl := Vector3(center.x - half, y, center.y - half)
	var br := Vector3(center.x + half, y, center.y - half)
	var ur := Vector3(center.x + half, y, center.y + half)
	var ul := Vector3(center.x - half, y, center.y + half)

	imesh.surface_add_vertex(bl)
	imesh.surface_add_vertex(br)
	imesh.surface_add_vertex(br)
	imesh.surface_add_vertex(ur)
	imesh.surface_add_vertex(ur)
	imesh.surface_add_vertex(ul)
	imesh.surface_add_vertex(ul)
	imesh.surface_add_vertex(bl)
	
func _build_filled_square(imesh: ImmediateMesh, center: Vector2, y: float, size: float) -> void:
	var half := size * 0.5

	var bl := Vector3(center.x - half, y, center.y - half)
	var br := Vector3(center.x + half, y, center.y - half)
	var ur := Vector3(center.x + half, y, center.y + half)
	var ul := Vector3(center.x - half, y, center.y + half)
	
	imesh.surface_add_vertex(bl)
	imesh.surface_add_vertex(br)
	imesh.surface_add_vertex(ur)

	imesh.surface_add_vertex(bl)
	imesh.surface_add_vertex(ur) 
	imesh.surface_add_vertex(ul) 

func draw_flat_cells(flats: Array[Dictionary]) -> void:
	flat.clear_surfaces()

	if flats.is_empty():
		flat_instance.mesh = flat
		return

	# Wireframe squares (same dimension as CELL_SIZE)
	for group in flats:
		flat.surface_begin(Mesh.PRIMITIVE_LINES, flat_material)
		var color_grp := Color(randf(), randf(), randf())
		flat.surface_set_color(color_grp)

		for cell in group["cells"]:
			_build_square(flat, cell, CELL_Y_OFFSET, CELL_SIZE)
		flat.surface_end()

	flat_instance.mesh = flat
	print("[RIVER] Drawing %d flat cells" % flats.size())

func draw_coast_cells(coasts: PackedVector2Array) -> void:
	coast.clear_surfaces()

	if coasts.is_empty():
		return

	#coast.surface_begin(Mesh.PRIMITIVE_LINES, coast_material)
	#for c in coasts:
	#	_build_filled_square(coast, c, CELL_Y_OFFSET + 0.2, CELL_SIZE)
	#coast.surface_end()

	coast.surface_begin(Mesh.PRIMITIVE_TRIANGLES, null)
	for c in coasts:
		_build_filled_square(coast, c, CELL_Y_OFFSET + 0.2, CELL_SIZE)
	coast.surface_end()
	
	coast_instance.mesh = coast
	print("[RIVER] Drawing %d coast cells" % coasts.size())

func draw_rivers(rivers: Array[PackedVector3Array]) -> void:
	# using bezier curve to build the path...
	
	mesh.clear_surfaces()

	for path in rivers:
		if path.size() < 2:
			continue
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
		for point in path:
			mesh.surface_add_vertex(Vector3(point.x, point.y + 2.0, point.z))
		mesh.surface_end()

	mesh_instance.mesh = mesh

func clear() -> void:
	mesh.clear_surfaces()
