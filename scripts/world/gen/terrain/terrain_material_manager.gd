class_name TerrainMaterialManager
extends RefCounted


func create_terrain_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(TerrainConfig.TERRAIN_SHADER_PATH)
	mat.set_shader_parameter("texture_scale", TerrainConfig.TEXTURE_SCALE)
	mat.set_shader_parameter("texture_strength", TerrainConfig.TEXTURE_STRENGTH)
	mat.set_shader_parameter("snow_height", TerrainConfig.SNOW_HEIGHT)
	mat.set_shader_parameter("snow_blend_range", TerrainConfig.SNOW_BLEND_RANGE)
	mat.set_shader_parameter("rock_slope_start", TerrainConfig.ROCK_SLOPE_START)
	mat.set_shader_parameter("rock_slope_end", TerrainConfig.ROCK_SLOPE_END)
	mat.set_shader_parameter("beach_height", TerrainConfig.BEACH_HEIGHT)
	mat.set_shader_parameter("grass_texture", load(TerrainConfig.GRASS_TEXTURE_PATH))
	mat.set_shader_parameter("sand_texture", load(TerrainConfig.SAND_TEXTURE_PATH))
	mat.set_shader_parameter("rock_texture", load(TerrainConfig.ROCK_TEXTURE_PATH))
	mat.set_shader_parameter("snow_texture", load(TerrainConfig.SNOW_TEXTURE_PATH))
	return mat
