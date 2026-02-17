class_name RiverVisualizer
extends Node3D

var mesh: ImmediateMesh
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D


func _ready() -> void:
	mesh = ImmediateMesh.new()

	mesh_instance = MeshInstance3D.new()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)

	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.5, 1.0)
	material.no_depth_test = true


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
