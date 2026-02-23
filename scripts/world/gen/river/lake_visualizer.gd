class_name LakeVisualizer
extends Node3D

var water_shader: Shader
var lake_material: ShaderMaterial


func _ready() -> void:
	water_shader = load("res://shaders/environment/water.gdshader")
	lake_material = ShaderMaterial.new()
	lake_material.shader = water_shader
	lake_material.set_shader_parameter("wave_height", 0.3)
	lake_material.set_shader_parameter("wave_speed", 0.3)
	lake_material.set_shader_parameter("wave_scale", 0.015)


func draw_lakes(lakes: Array[Dictionary]) -> void:
	# Clear previous lake meshes
	for child in get_children():
		child.queue_free()

	for i in range(lakes.size()):
		var lake: Dictionary = lakes[i]
		var bounds: Rect2 = lake["world_bounds"]
		var water_level: float = lake["water_level"]
		var cell_count: int = lake["cells"].size()

		if cell_count < 4:
			continue

		var plane := PlaneMesh.new()
		plane.size = Vector2(bounds.size.x, bounds.size.y)
		plane.subdivide_width = clampi(int(bounds.size.x / 10.0), 2, 32)
		plane.subdivide_depth = clampi(int(bounds.size.y / 10.0), 2, 32)

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = plane
		mesh_instance.material_override = lake_material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var center_x := bounds.position.x + bounds.size.x / 2.0
		var center_z := bounds.position.y + bounds.size.y / 2.0
		mesh_instance.position = Vector3(center_x, water_level, center_z)

		add_child(mesh_instance)

	print("[LAKE] Drawing %d lakes" % get_child_count())
