shader_type spatial;

uniform float curvature : hint_range(0.0, 0.01) = 0.0008;
uniform float curvature_start : hint_range(0.0, 200.0) = 50.0;

uniform sampler2D grass_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_texture  : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_texture  : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_texture  : source_color, filter_linear_mipmap, repeat_enable;

uniform float texture_scale : hint_range(1.0, 100.0) = 20.0;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.5;

varying vec3 vertex_color_srgb;
varying vec3 world_pos;

vec3 srgb_to_linear(vec3 srgb) {
	return mix(
		srgb / 12.92,
		pow((srgb + 0.055) / 1.055, vec3(2.4)),
		step(0.04045, srgb)
	);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 camera_world_pos = INV_VIEW_MATRIX[3].xyz;

	vec2 offset = world_pos.xz - camera_world_pos.xz;
	float dist = length(offset);
	float effective_dist = max(0.0, dist - curvature_start);
	float curve_amount = effective_dist * effective_dist * curvature;

	world_pos.y -= curve_amount;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_pos, 1.0)).xyz;

	vertex_color_srgb = COLOR.rgb;
}

void fragment() {
	vec3 linear_color = srgb_to_linear(vertex_color_srgb);
	vec3 col = vertex_color_srgb;
	vec2 uv_world = world_pos.xz / texture_scale;

	// Biome detection from vertex color
	// Grass: Plains(0.3,0.65,0.2), Forest(0.15,0.5,0.15), Jungle(0.1,0.55,0.1), Hills(0.4,0.55,0.3)
	float green_dominance = col.g - max(col.r, col.b);
	float grass_mask = smoothstep(0.05, 0.2, green_dominance);

	// Sand: Beach(0.9,0.85,0.6), Desert(0.94,0.87,0.5)
	// warm yellows, high r+g, lower b
	float sand_mask = smoothstep(0.45, 0.6, min(col.r, col.g)) * smoothstep(0.65, 0.55, col.b);

	// Snow: Tundra(0.75,0.8,0.75), Snow Peaks(0.95,0.97,1.0)
	// all channels high
	float snow_mask = smoothstep(0.65, 0.8, min(min(col.r, col.g), col.b));

	// Rock: Mountains(0.5,0.48,0.45)
	// whatever isn't covered by other masks
	float rock_mask = 1.0 - max(max(grass_mask, sand_mask), snow_mask);
	rock_mask = max(rock_mask, 0.0);

	// Sample all textures
	vec3 grass_sample = texture(grass_texture, uv_world).rgb;
	vec3 sand_sample  = texture(sand_texture, uv_world).rgb;
	vec3 rock_sample  = texture(rock_texture, uv_world).rgb;
	vec3 snow_sample  = texture(snow_texture, uv_world).rgb;

	// Blend textures weighted by biome masks
	vec3 tex_color = grass_sample * grass_mask
	               + sand_sample * sand_mask
	               + rock_sample * rock_mask
	               + snow_sample * snow_mask;

	// Modulate vertex color with texture
	ALBEDO = mix(linear_color, linear_color * tex_color, texture_strength);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	AO = 1.0;
	AO_LIGHT_AFFECT = 0.5;
}
