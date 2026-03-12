class_name RiverVisualizer
extends Node3D

const CELL_SIZE := 64.0
const CELL_Y_OFF := 1.5

var r_mesh: ImmediateMesh
var r_instance: MeshInstance3D
var r_mat: StandardMaterial3D

var cand_mesh: ImmediateMesh
var cand_instance: MeshInstance3D
var cand_mat: StandardMaterial3D

var coast_mesh: ImmediateMesh
var coast_instance: MeshInstance3D
var coast_mat: StandardMaterial3D

var flat_mesh: ImmediateMesh
var flat_instance: MeshInstance3D
var flat_mat: StandardMaterial3D

func _ready() -> void:
	r_mesh = ImmediateMesh.new()
	cand_mesh = ImmediateMesh.new()
	coast_mesh = ImmediateMesh.new()
	flat_mesh = ImmediateMesh.new()

	r_instance = MeshInstance3D.new()
	r_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(r_instance)

	cand_instance = MeshInstance3D.new()
	cand_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cand_instance)

	coast_instance = MeshInstance3D.new()
	coast_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(coast_instance)

	flat_instance = MeshInstance3D.new()
	flat_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flat_instance)

	r_mat = StandardMaterial3D.new()
	r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	r_mat.albedo_color = Color(0.2, 0.5, 1.0)
	r_mat.no_depth_test = true

	cand_mat = StandardMaterial3D.new()
	cand_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cand_mat.albedo_color = Color.YELLOW
	cand_mat.no_depth_test = true

	coast_mat = StandardMaterial3D.new()
	coast_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	coast_mat.albedo_color = Color(0.85, 0.33, 0.19)
	coast_mat.no_depth_test = true

	flat_mat = StandardMaterial3D.new()
	flat_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat_mat.no_depth_test = true
	flat_mat.albedo_color = Color.WHITE
	flat_mat.vertex_color_use_as_albedo = true


func draw_candidates(candidates: Array[Vector3]) -> void:
	cand_mesh.clear_surfaces()
	var sz := 10.0
	cand_mesh.surface_begin(Mesh.PRIMITIVE_LINES, cand_mat)
	for p in candidates:
		var v := Vector3(p.x, p.y + 2.0, p.z)
		cand_mesh.surface_add_vertex(v + Vector3(-sz, 0, 0))
		cand_mesh.surface_add_vertex(v + Vector3(sz, 0, 0))
		cand_mesh.surface_add_vertex(v + Vector3(0, 0, -sz))
		cand_mesh.surface_add_vertex(v + Vector3(0, 0, sz))
	cand_mesh.surface_end()
	cand_instance.mesh = cand_mesh


func _draw_sq(m: ImmediateMesh, center: Vector2, y: float, size: float) -> void:
	var h := size * 0.5
	var bl := Vector3(center.x - h, y, center.y - h)
	var br := Vector3(center.x + h, y, center.y - h)
	var ur := Vector3(center.x + h, y, center.y + h)
	var ul := Vector3(center.x - h, y, center.y + h)

	m.surface_add_vertex(bl); m.surface_add_vertex(br)
	m.surface_add_vertex(br); m.surface_add_vertex(ur)
	m.surface_add_vertex(ur); m.surface_add_vertex(ul)
	m.surface_add_vertex(ul); m.surface_add_vertex(bl)


func _draw_filled_sq(m: ImmediateMesh, center: Vector2, y: float, size: float) -> void:
	var h := size * 0.5
	var bl := Vector3(center.x - h, y, center.y - h)
	var br := Vector3(center.x + h, y, center.y - h)
	var ur := Vector3(center.x + h, y, center.y + h)
	var ul := Vector3(center.x - h, y, center.y + h)
	
	m.surface_add_vertex(bl); m.surface_add_vertex(br); m.surface_add_vertex(ur)
	m.surface_add_vertex(bl); m.surface_add_vertex(ur); m.surface_add_vertex(ul)


func draw_flat_cells(groups: Array[Dictionary]) -> void:
	flat_mesh.clear_surfaces()
	if groups.is_empty(): return

	for grp in groups:
		flat_mesh.surface_begin(Mesh.PRIMITIVE_LINES, flat_mat)
		var c := Color(randf(), randf(), randf())
		flat_mesh.surface_set_color(c)
		for cell in grp["cells"]:
			_draw_sq(flat_mesh, cell, CELL_Y_OFF, CELL_SIZE)
		flat_mesh.surface_end()
	flat_instance.mesh = flat_mesh


func draw_coast_cells(coasts: PackedVector2Array) -> void:
	coast_mesh.clear_surfaces()
	if coasts.is_empty(): return

	coast_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, coast_mat)
	for c in coasts:
		_draw_filled_sq(coast_mesh, c, CELL_Y_OFF + 0.2, CELL_SIZE)
	coast_mesh.surface_end()
	coast_instance.mesh = coast_mesh


func draw_rivers(rivers: Array[PackedVector3Array]) -> void:
	r_mesh.clear_surfaces()
	for path in rivers:
		if path.size() < 2: continue
		r_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, r_mat)
		for p in path:
			r_mesh.surface_add_vertex(Vector3(p.x, p.y + 2.0, p.z))
		r_mesh.surface_end()
	r_instance.mesh = r_mesh

func clear() -> void:
	r_mesh.clear_surfaces()
	cand_mesh.clear_surfaces()
	coast_mesh.clear_surfaces()
	flat_mesh.clear_surfaces()
