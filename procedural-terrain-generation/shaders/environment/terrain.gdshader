shader_type spatial;

uniform sampler2D grass_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_texture  : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_texture  : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_texture  : source_color, filter_linear_mipmap, repeat_enable;

uniform float texture_scale : hint_range(1.0, 100.0) = 20.0;
uniform float texture_strength : hint_range(0.0, 1.0) = 0.65;

uniform float snow_height : hint_range(20.0, 250.0) = 120.0;
uniform float snow_blend_range : hint_range(5.0, 50.0) = 30.0;
uniform float rock_slope_start : hint_range(0.1, 0.9) = 0.55;
uniform float rock_slope_end : hint_range(0.1, 0.9) = 0.35;
uniform float beach_height : hint_range(0.0, 15.0) = 3.0;

varying vec3 climate_data;
varying vec3 world_pos;
varying vec3 world_normal;
varying float terrain_height;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_height = world_pos.y;
	climate_data = COLOR.rgb;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float temperature = climate_data.r;
	float moisture = climate_data.g;
	float continentalness = climate_data.b;

	float h = terrain_height;
	vec3 wn = normalize(world_normal);
	float slope = 1.0 - wn.y;

	// Transition noise to break up sharp horizontal boundaries
	float tn = (value_noise(world_pos.xz * 0.06) - 0.5) * 10.0;

	vec2 uv = world_pos.xz / texture_scale;

	// above snow line, shifted by temperature (hot = higher snow line)
	float eff_snow = snow_height + (temperature - 0.5) * 70.0 + tn;
	float snow_w = smoothstep(eff_snow, eff_snow + snow_blend_range, h);
	snow_w *= smoothstep(0.7, 0.4, slope);

	float slope_rock = smoothstep(rock_slope_end, rock_slope_start, slope);
	float alt_rock = smoothstep(40.0 + tn, 90.0 + tn, h) * 0.7;
	float rock_w = max(slope_rock, alt_rock) * (1.0 - snow_w);

	// beach near sea level OR hot+dry desert
	float beach_sand = smoothstep(beach_height + tn * 0.3, -1.0, h)
	                 * smoothstep(0.3, 0.5, continentalness);
	float desert_sand = smoothstep(0.65, 0.8, temperature)
	                  * smoothstep(0.45, 0.3, moisture)
	                  * smoothstep(0.4, 0.5, continentalness);
	float sand_w = max(beach_sand, desert_sand) * (1.0 - snow_w) * (1.0 - slope_rock);

	// everything else is grass
	float grass_w = max(1.0 - snow_w - rock_w - sand_w, 0.0);

	float total = grass_w + sand_w + rock_w + snow_w;
	total = max(total, 0.001);
	grass_w /= total;
	sand_w /= total;
	rock_w /= total;
	snow_w /= total;

	vec3 grass_s = texture(grass_texture, uv).rgb;
	vec3 sand_s  = texture(sand_texture, uv).rgb;
	vec3 rock_s  = texture(rock_texture, uv).rgb;
	vec3 snow_s  = texture(snow_texture, uv).rgb;

	vec3 tex_blend = grass_s * grass_w + sand_s * sand_w + rock_s * rock_w + snow_s * snow_w;

	vec3 grass_tint = mix(
		vec3(0.65, 0.55, 0.25),
		vec3(0.2, 0.65, 0.1),
		moisture
	);
	grass_tint = mix(
		vec3(0.45, 0.6, 0.35),
		grass_tint,
		smoothstep(0.3, 0.6, temperature)
	);

	vec3 base_tint = grass_tint * grass_w
	               + vec3(0.95, 0.88, 0.55) * sand_w
	               + vec3(0.55, 0.5, 0.45) * rock_w
	               + vec3(0.95, 0.97, 1.0) * snow_w;

	vec3 final_color = mix(base_tint, base_tint * tex_blend, texture_strength);

	if (h < 0.0) {
		float depth_factor = clamp(-h / 60.0, 0.0, 0.8);
		vec3 shallow_tint = vec3(0.6, 0.75, 0.55);  // sandy-green shallows
		vec3 deep_tint = vec3(0.1, 0.25, 0.4);       // dark blue depths
		vec3 underwater_color = mix(shallow_tint, deep_tint, depth_factor);
		final_color = mix(final_color, underwater_color, depth_factor * 0.8);
	}

	ALBEDO = final_color;
	ROUGHNESS = mix(0.9, 1.0, rock_w);
	METALLIC = 0.0;
	AO = 1.0;
	AO_LIGHT_AFFECT = 0.5;
}
