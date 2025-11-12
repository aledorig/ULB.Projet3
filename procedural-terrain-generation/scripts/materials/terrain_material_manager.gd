class_name TerrainMaterialManager
extends RefCounted

func create_terrain_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.5, 0.25)  # Forest green
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.metallic = 0.0
	mat.roughness = 0.85
	mat.rim_enabled = true
	mat.rim = 0.4
	mat.rim_tint = 0.2
	return mat

func create_water_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.4, 0.8, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.8
	mat.roughness = 0.1
	mat.rim_enabled = true
	return mat

func create_grass_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.7, 0.2)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	return mat

func get_terrain_color_for_height(height: float) -> Color:
	# Example: Darker green in valleys, lighter on hills
	if height < -5.0:
		return Color(0.2, 0.4, 0.2)  # Dark green (valleys)
	elif height > 15.0:
		return Color(0.5, 0.5, 0.5)  # Gray (mountain peaks)
	else:
		return Color(0.25, 0.5, 0.25)  # Standard green
