class_name WaterManager
extends MeshInstance3D

@export var water_size:    float = 2000.0
@export var follow_camera: bool = true

var camera: Camera3D
var water_material: ShaderMaterial

func _ready() -> void:
	_setup_water_mesh()
	_setup_water_material()
	camera = get_viewport().get_camera_3d()
	position.y = TerrainConstants.SEA_LEVEL
	GameSettingsAutoload.runtime_settings_changed.connect(_on_settings_changed)


func _setup_water_mesh() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(water_size, water_size)
	plane.subdivide_width = 64
	plane.subdivide_depth = 64
	mesh = plane


func _setup_water_material() -> void:
	var shader := load("res://shaders/environment/water.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("water_color", Color(0.1, 0.35, 0.55))
	mat.set_shader_parameter("water_deep_color", Color(0.02, 0.12, 0.25))
	mat.set_shader_parameter("water_clarity", 0.3)
	mat.set_shader_parameter("roughness", 0.05)
	mat.set_shader_parameter("wave_speed", 0.4)
	mat.set_shader_parameter("wave_scale", 0.015)
	mat.set_shader_parameter("wave_height", 0.2)
	mat.set_shader_parameter("fresnel_power", 4.0)
	mat.set_shader_parameter("curvature", GameSettingsAutoload.curvature)
	mat.set_shader_parameter("curvature_start", GameSettingsAutoload.curvature_start)
	water_material = mat
	material_override = mat


func _on_settings_changed() -> void:
	if water_material:
		water_material.set_shader_parameter("curvature", GameSettingsAutoload.curvature)
		water_material.set_shader_parameter("curvature_start", GameSettingsAutoload.curvature_start)


func _process(_delta: float) -> void:
	if follow_camera and camera:
		position.x = camera.global_position.x
		position.z = camera.global_position.z
