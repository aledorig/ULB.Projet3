class_name TerrainMaterialManager
extends RefCounted

func create_terrain_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	
	mat.albedo_color = Color(0.177, 0.57, 0.196, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 1.0
	mat.metallic = 0.0
	
	# Reduce ambient light contribution to make terrain darker
	mat.ao_enabled = true
	mat.ao_light_affect = 0.5
	
	# Keep shadows working
	mat.shadow_to_opacity = false

	return mat
