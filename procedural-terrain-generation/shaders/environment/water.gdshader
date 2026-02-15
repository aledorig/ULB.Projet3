shader_type spatial;

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Water appearance
uniform vec3 water_color : source_color = vec3(0.1, 0.3, 0.5);
uniform vec3 water_deep_color : source_color = vec3(0.02, 0.1, 0.2);
uniform float water_clarity : hint_range(0.0, 1.0) = 0.3;
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

// Wave animation
uniform float wave_speed : hint_range(0.0, 2.0) = 0.5;
uniform float wave_scale : hint_range(0.001, 0.1) = 0.02;
uniform float wave_height : hint_range(0.0, 2.0) = 0.3;

// Fresnel
uniform float fresnel_power : hint_range(1.0, 10.0) = 5.0;

// World curvature (must match terrain shader)
uniform float curvature : hint_range(0.0, 0.01) = 0.0003;
uniform float curvature_start : hint_range(0.0, 200.0) = 120.0;

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

	// Apply world curvature (same as terrain)
	vec3 camera_world_pos = INV_VIEW_MATRIX[3].xyz;
	vec2 offset = world_pos.xz - camera_world_pos.xz;
	float dist = length(offset);
	float effective_dist = max(0.0, dist - curvature_start);
	float curve_amount = effective_dist * effective_dist * curvature;

	// Modify world position with wave and curvature
	world_pos.y += wave_offset;
	world_pos.y -= curve_amount;

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

	// Mix between water color and deep color based on fresnel
	vec3 final_color = mix(water_color, water_deep_color, 1.0 - fresnel);

	// Add slight sky reflection tint at edges
	vec3 sky_tint = vec3(0.4, 0.6, 0.8);
	final_color = mix(final_color, sky_tint, fresnel * 0.3);

	ALBEDO = final_color;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	NORMAL = world_normal;
	ALPHA = mix(0.7, 0.95, fresnel);
}
