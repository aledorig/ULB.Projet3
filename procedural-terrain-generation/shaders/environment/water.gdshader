shader_type spatial;

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Water appearance
uniform vec3 water_shallow_color : source_color = vec3(0.1, 0.55, 0.6);   // turquoise coastal
uniform vec3 water_mid_color : source_color = vec3(0.05, 0.3, 0.55);      // medium blue
uniform vec3 water_deep_color : source_color = vec3(0.01, 0.05, 0.15);    // dark ocean
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

// Wave animation
uniform float wave_speed : hint_range(0.0, 2.0) = 0.5;
uniform float wave_scale : hint_range(0.001, 0.1) = 0.02;
uniform float wave_height : hint_range(0.0, 2.0) = 0.3;

// Fresnel
uniform float fresnel_power : hint_range(1.0, 10.0) = 5.0;

// Depth coloring
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Simple wave animation using two sine waves
	float wave1 = sin(world_pos.x * wave_scale * 10.0 + TIME * wave_speed) *
	              cos(world_pos.z * wave_scale * 8.0 + TIME * wave_speed * 0.7);
	float wave2 = sin(world_pos.x * wave_scale * 7.0 - TIME * wave_speed * 0.5) *
	              cos(world_pos.z * wave_scale * 12.0 + TIME * wave_speed * 0.3);

	float wave_offset = (wave1 + wave2) * wave_height * 0.5;

	// Apply wave to world position
	world_pos.y += wave_offset;

	// Convert back to local space
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_pos, 1.0)).xyz;

	// Approximate normal from wave displacement
	float dx = cos(world_pos.x * wave_scale * 10.0 + TIME * wave_speed) * wave_scale * 10.0 * wave_height;
	float dz = -sin(world_pos.z * wave_scale * 8.0 + TIME * wave_speed * 0.7) * wave_scale * 8.0 * wave_height;
	world_normal = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	// Fresnel effect - more reflective at glancing angles
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	float fresnel = pow(1.0 - max(dot(world_normal, view_dir), 0.0), fresnel_power);

	// Depth-based coloring: read scene depth to determine water depth
	float screen_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, screen_depth, 1.0);
	vec4 view_coords = INV_PROJECTION_MATRIX * ndc;
	view_coords.xyz /= view_coords.w;
	float water_depth = VERTEX.z - view_coords.z; // positive = deeper

	// Blend shallow → mid → deep based on depth
	float shallow_factor = smoothstep(0.0, 8.0, water_depth);   // 0-8 units: shallow
	float deep_factor = smoothstep(8.0, 40.0, water_depth);      // 8-40 units: mid→deep

	vec3 depth_color = mix(water_shallow_color, water_mid_color, shallow_factor);
	depth_color = mix(depth_color, water_deep_color, deep_factor);

	// Add sky reflection at glancing angles
	vec3 sky_tint = vec3(0.45, 0.65, 0.85);
	vec3 final_color = mix(depth_color, sky_tint, fresnel * 0.35);

	// Specular highlight boost for sun
	float specular_boost = pow(max(dot(reflect(-view_dir, world_normal), normalize(vec3(0.3, 0.8, 0.5))), 0.0), 64.0);
	final_color += vec3(1.0, 0.95, 0.85) * specular_boost * 0.3;

	ALBEDO = final_color;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	NORMAL = world_normal;
	ALPHA = mix(0.6, 0.95, shallow_factor);
}
