class_name TerrainMaterialManager
extends RefCounted

const TERRAIN_SHADER_PATH := "res://shaders/environment/terrain.gdshader"
const GRASS_TEXTURE_PATH  := "res://assets/textures/grass.png"
const SAND_TEXTURE_PATH   := "res://assets/textures/sand.png"
const ROCK_TEXTURE_PATH   := "res://assets/textures/rock.png"
const SNOW_TEXTURE_PATH   := "res://assets/textures/snow.png"

const DEFAULT_CURVATURE:        float = 0.0008
const DEFAULT_CURVATURE_START:  float = 50.0
const DEFAULT_TEXTURE_SCALE:    float = 20.0
const DEFAULT_TEXTURE_STRENGTH: float = 0.5

func create_terrain_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(TERRAIN_SHADER_PATH)
	mat.set_shader_parameter("curvature", DEFAULT_CURVATURE)
	mat.set_shader_parameter("curvature_start", DEFAULT_CURVATURE_START)
	mat.set_shader_parameter("texture_scale", DEFAULT_TEXTURE_SCALE)
	mat.set_shader_parameter("texture_strength", DEFAULT_TEXTURE_STRENGTH)
	mat.set_shader_parameter("grass_texture", load(GRASS_TEXTURE_PATH))
	mat.set_shader_parameter("sand_texture", load(SAND_TEXTURE_PATH))
	mat.set_shader_parameter("rock_texture", load(ROCK_TEXTURE_PATH))
	mat.set_shader_parameter("snow_texture", load(SNOW_TEXTURE_PATH))
	return mat
