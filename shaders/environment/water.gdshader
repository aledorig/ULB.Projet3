shader_type spatial;

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 water_shallow_color : source_color = vec3(0.08, 0.45, 0.65);
uniform vec3 water_mid_color : source_color = vec3(0.03, 0.2, 0.5);
uniform vec3 water_deep_color : source_color = vec3(0.01, 0.04, 0.12);
uniform vec3 foam_color : source_color = vec3(0.85, 0.9, 0.95);
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

uniform float wave_speed : hint_range(0.0, 2.0) = 0.5;
uniform float wave_scale : hint_range(0.001, 0.1) = 0.02;
uniform float wave_height : hint_range(0.0, 10.0) = 3.0;

uniform float fresnel_power : hint_range(1.0, 10.0) = 3.0;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_pos;
varying vec3 world_normal;
varying float wave_crest;
varying float cam_dist;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float dist = length(world_pos.xz - CAMERA_POSITION_WORLD.xz);
	cam_dist = dist;

	// LOD factor
	float lod_med = 1.0 - smoothstep(150.0, 400.0, dist);  // medium detail fades 150-400
	float lod_hi  = 1.0 - smoothstep(60.0, 200.0, dist);   // high detail fades 60-200

	float t = TIME * wave_speed;
	float h = wave_height;

	float w1 = sin(world_pos.x * wave_scale * 4.0 + t * 0.7)
	         * cos(world_pos.z * wave_scale * 3.0 + t * 0.5);

	float w2 = sin(world_pos.x * wave_scale * 7.0 - t * 0.6 + world_pos.z * wave_scale * 5.0)
	         * cos(world_pos.z * wave_scale * 9.0 + t * 0.4);

	float w3 = sin(world_pos.x * wave_scale * 14.0 + t * 1.3)
	         * sin(world_pos.z * wave_scale * 12.0 - t * 1.1);

	float w4 = sin(world_pos.x * wave_scale * 22.0 + t * 1.6)
	         * cos(world_pos.z * wave_scale * 19.0 - t * 1.4);

	float diag = (world_pos.x * 0.7 + world_pos.z * 0.7) * wave_scale * 5.0;
	float w5 = sin(diag + t * 0.9) * 0.7;

	// combine with LOD weighting
	float combined = w1 * 0.35
	               + w5 * 0.2
	               + w2 * 0.25 * lod_med
	               + w3 * 0.12 * lod_hi
	               + w4 * 0.08 * lod_hi;

	float wave_offset = combined * h;

	wave_crest = clamp(combined * 0.5 + 0.5, 0.0, 1.0);

	world_pos.y += wave_offset;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_pos, 1.0)).xyz;

	float dx = (cos(world_pos.x * wave_scale * 4.0 + t * 0.7) * wave_scale * 4.0 * 0.35
	          + cos(world_pos.x * wave_scale * 7.0 - t * 0.6 + world_pos.z * wave_scale * 5.0) * wave_scale * 7.0 * 0.25 * lod_med
	          + cos(world_pos.x * wave_scale * 14.0 + t * 1.3) * wave_scale * 14.0 * 0.12 * lod_hi) * h;
	float dz = (-sin(world_pos.z * wave_scale * 3.0 + t * 0.5) * wave_scale * 3.0 * 0.35
	          + cos(world_pos.z * wave_scale * 9.0 + t * 0.4) * wave_scale * 9.0 * 0.25 * lod_med
	          - cos(world_pos.z * wave_scale * 12.0 - t * 1.1) * wave_scale * 12.0 * 0.12 * lod_hi) * h;
	world_normal = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	float fresnel = pow(1.0 - max(dot(world_normal, view_dir), 0.0), fresnel_power);

	float screen_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, screen_depth, 1.0);
	vec4 view_coords = INV_PROJECTION_MATRIX * ndc;
	view_coords.xyz /= view_coords.w;
	float water_depth = VERTEX.z - view_coords.z;

	float shore_factor = smoothstep(0.0, 3.0, water_depth);
	float shallow_factor = smoothstep(3.0, 12.0, water_depth);
	float deep_factor = smoothstep(12.0, 50.0, water_depth);

	vec3 shore_color = mix(vec3(0.3, 0.6, 0.7), water_shallow_color, shore_factor);
	vec3 depth_color = mix(shore_color, water_mid_color, shallow_factor);
	depth_color = mix(depth_color, water_deep_color, deep_factor);

	float shore_foam = (1.0 - shore_factor) * 0.6;
	float foam_wave = sin(world_pos.x * 0.3 + TIME * 1.5) * 0.5 + 0.5;
	foam_wave *= sin(world_pos.z * 0.25 + TIME * 1.2) * 0.5 + 0.5;
	shore_foam *= smoothstep(0.3, 0.7, foam_wave);

	float crest_foam = smoothstep(0.72, 0.92, wave_crest) * 0.4;
	crest_foam *= mix(0.3, 1.0, shallow_factor);

	float total_foam = min(shore_foam + crest_foam, 0.8);

	vec3 sky_tint = vec3(0.45, 0.65, 0.85);
	vec3 final_color = mix(depth_color, sky_tint, fresnel * 0.35);

	final_color = mix(final_color, foam_color, total_foam);

	float specular_boost = pow(max(dot(reflect(-view_dir, world_normal), normalize(vec3(0.3, 0.8, 0.5))), 0.0), 64.0);
	final_color += vec3(1.0, 0.95, 0.85) * specular_boost * 0.3;

	ALBEDO = final_color;
	ROUGHNESS = mix(roughness, 0.4, total_foam);
	METALLIC = metallic;
	NORMAL = world_normal;
	ALPHA = mix(0.45, 0.95, shore_factor);
}
