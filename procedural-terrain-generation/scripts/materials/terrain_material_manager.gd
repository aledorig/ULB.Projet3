class_name TerrainMaterialManager
extends RefCounted

func create_terrain_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	
	# Enable vertex colors for biome blending
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	
	# Base material properties
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness    = 1.0
	mat.metallic     = 0.0
	
	# Ambient and lighting
	mat.ao_enabled      = true
	mat.ao_light_affect = 0.5
	
	# Keep shadows working
	mat.shadow_to_opacity = false
	
	return mat

func create_biome_shader() -> Shader:
	# Create a custom shader for better biome blending
	var shader_code = """
	shader_type spatial;

	// Biome texture uniforms
	uniform sampler2D sand_texture  : source_color;
	uniform sampler2D grass_texture : source_color;
	uniform sampler2D rock_texture  : source_color;
	uniform sampler2D snow_texture  : source_color;

	uniform float texture_scale = 20.0;
	uniform float snow_line = 25.0;

	varying vec3 world_pos;
	varying vec3 vertex_color;

	void vertex() {
		world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vertex_color = COLOR.rgb;
	}

	void fragment() {
		// Use vertex color for now (can blend textures later)
		vec3 base_color = vertex_color;
		
		// Add snow at high altitudes
		float snow_factor = smoothstep(snow_line, snow_line + 15.0, world_pos.y);
		vec3 snow_color = vec3(0.95, 0.95, 1.0);
		
		// Blend with snow
		ALBEDO = mix(base_color, snow_color, snow_factor);
		
		// Roughness varies by biome
		ROUGHNESS = mix(1.0, 0.7, snow_factor);
		METALLIC = 0.0;
	}
	"""
	
	var shader = Shader.new()
	shader.code = shader_code
	return shader

func create_biome_material() -> ShaderMaterial:
	var mat = ShaderMaterial.new()
	mat.shader = create_biome_shader()
	mat.set_shader_parameter("texture_scale", 20.0)
	mat.set_shader_parameter("snow_line", 25.0)
	return mat
