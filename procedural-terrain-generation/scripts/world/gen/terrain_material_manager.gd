class_name TerrainMaterialManager
extends RefCounted

const TERRAIN_SHADER_PATH := "res://shaders/environment/terrain.gdshader"
const GRASS_TEXTURE_PATH  := "res://assets/textures/grass.png"
const SAND_TEXTURE_PATH   := "res://assets/textures/sand.png"
const ROCK_TEXTURE_PATH   := "res://assets/textures/rock.png"
const SNOW_TEXTURE_PATH   := "res://assets/textures/snow.png"

const DEFAULT_TEXTURE_SCALE:    float = 20.0
const DEFAULT_TEXTURE_STRENGTH: float = 0.65

const DEFAULT_SNOW_HEIGHT:      float = 120.0
const DEFAULT_SNOW_BLEND_RANGE: float = 30.0
const DEFAULT_ROCK_SLOPE_START: float = 0.55
const DEFAULT_ROCK_SLOPE_END:   float = 0.35
const DEFAULT_BEACH_HEIGHT:     float = 3.0

func create_terrain_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(TERRAIN_SHADER_PATH)
	mat.set_shader_parameter("texture_scale", DEFAULT_TEXTURE_SCALE)
	mat.set_shader_parameter("texture_strength", DEFAULT_TEXTURE_STRENGTH)
	mat.set_shader_parameter("snow_height", DEFAULT_SNOW_HEIGHT)
	mat.set_shader_parameter("snow_blend_range", DEFAULT_SNOW_BLEND_RANGE)
	mat.set_shader_parameter("rock_slope_start", DEFAULT_ROCK_SLOPE_START)
	mat.set_shader_parameter("rock_slope_end", DEFAULT_ROCK_SLOPE_END)
	mat.set_shader_parameter("beach_height", DEFAULT_BEACH_HEIGHT)
	mat.set_shader_parameter("grass_texture", load(GRASS_TEXTURE_PATH))
	mat.set_shader_parameter("sand_texture", load(SAND_TEXTURE_PATH))
	mat.set_shader_parameter("rock_texture", load(ROCK_TEXTURE_PATH))
	mat.set_shader_parameter("snow_texture", load(SNOW_TEXTURE_PATH))
	return mat
