class_name TerrainMaterialManager
extends RefCounted

## Creates and manages terrain materials and shaders

# CURVATURE SETTINGS

const DEFAULT_CURVATURE:       float = 0.0008
const DEFAULT_CURVATURE_START: float = 50.0

# MATERIAL CREATION

func create_terrain_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _create_terrain_shader()
	mat.set_shader_parameter("curvature", DEFAULT_CURVATURE)
	mat.set_shader_parameter("curvature_start", DEFAULT_CURVATURE_START)
	return mat


func _create_terrain_shader() -> Shader:
	# - vertex_color_use_as_albedo = true
	# - vertex_color_is_srgb = true
	# - shading_mode = PER_PIXEL
	# - roughness = 1.0
	# - metallic = 0.0
	# - ao_enabled = true
	# - ao_light_affect = 0.5
	
	var shader_code := """
shader_type spatial;

// Curvature settings
uniform float curvature : hint_range(0.0, 0.01) = 0.0008;
uniform float curvature_start : hint_range(0.0, 200.0) = 50.0;

// Vertex color (sRGB)
varying vec3 vertex_color_srgb;

// sRGB to linear conversion (matches vertex_color_is_srgb = true)
vec3 srgb_to_linear(vec3 srgb) {
	return mix(
		srgb / 12.92,
		pow((srgb + 0.055) / 1.055, vec3(2.4)),
		step(0.04045, srgb)
	);
}

void vertex() {
	// World curvature
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 camera_world_pos = INV_VIEW_MATRIX[3].xyz;
	
	vec2 offset = world_pos.xz - camera_world_pos.xz;
	float dist = length(offset);
	float effective_dist = max(0.0, dist - curvature_start);
	float curve_amount = effective_dist * effective_dist * curvature;
	
	world_pos.y -= curve_amount;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_pos, 1.0)).xyz;
	
	// Pass vertex color as sRGB (will convert in fragment)
	vertex_color_srgb = COLOR.rgb;
}

void fragment() {
	// Convert sRGB vertex color to linear (matches vertex_color_is_srgb = true)
	vec3 linear_color = srgb_to_linear(vertex_color_srgb);
	
	ALBEDO = linear_color;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	AO = 1.0;
	AO_LIGHT_AFFECT = 0.5;
}
"""
	
	var shader := Shader.new()
	shader.code = shader_code
	return shader

# SHADER CREATION

func create_biome_shader() -> Shader:
	var shader_code := """
shader_type spatial;

// Biome texture uniforms (for future use)
uniform sampler2D sand_texture : source_color;
uniform sampler2D grass_texture : source_color;
uniform sampler2D rock_texture : source_color;
uniform sampler2D snow_texture : source_color;

uniform float texture_scale = 20.0;
uniform float snow_line = 25.0;

varying vec3 world_pos;
varying vec3 vertex_color;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vertex_color = COLOR.rgb;
}

void fragment() {
	vec3 base_color = vertex_color;
	
	// Snow at high altitudes
	float snow_factor = smoothstep(snow_line, snow_line + 15.0, world_pos.y);
	vec3 snow_color = vec3(0.95, 0.95, 1.0);
	
	ALBEDO = mix(base_color, snow_color, snow_factor);
	ROUGHNESS = mix(1.0, 0.7, snow_factor);
	METALLIC = 0.0;
}
"""
	
	var shader := Shader.new()
	shader.code = shader_code
	return shader


func create_biome_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = create_biome_shader()
	mat.set_shader_parameter("texture_scale", 20.0)
	mat.set_shader_parameter("snow_line", 25.0)
	return mat
