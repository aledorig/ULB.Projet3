// =============================================================================
// Water Surface: animated ocean with depth-based coloring and foam
// =============================================================================
//
// Renders a translucent water plane with:
//   - Vertex-displaced waves (5 overlapping sine layers with distance LOD)
//   - Depth-based color gradient (shallow -> mid -> deep, read from depth buffer)
//   - Shore foam (near terrain where water meets land)
//   - Fresnel reflection tint and sun specular highlight
//
// UNIFORMS (what to tweak):
//   water_shallow/mid/deep_color -- color gradient from shore to open ocean
//   foam_color                   -- white foam on shoreline
//   wave_speed                   -- how fast waves move (0 = frozen)
//   wave_scale                   -- frequency of waves (smaller = wider waves)
//   wave_height                  -- amplitude of vertex displacement
//   fresnel_power                -- edge reflection intensity (higher = thinner rim)
//   roughness / metallic         -- PBR surface properties
//
// VERTEX:  displaces mesh vertices with 5 sine wave layers, fading detail
//          by distance (LOD) to save GPU. Computes analytical normals.
// FRAGMENT: reads depth buffer for water-over-terrain depth, blends 3 depth
//           colors, adds shore foam, fresnel sky tint, sun specular.
// =============================================================================

shader_type spatial;

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// LOD fade distances (world units from camera)
const float LOD_MED_START = 150.0;  // medium-detail waves start fading here
const float LOD_MED_END   = 400.0;  // medium-detail waves fully gone here
const float LOD_HI_START  = 60.0;   // high-detail ripples start fading here
const float LOD_HI_END    = 200.0;  // high-detail ripples fully gone here

// Depth zone boundaries (world units below water surface)
const float DEPTH_SHORE   = 3.0;    // shore/beach zone boundary
const float DEPTH_SHALLOW = 12.0;   // shallow water zone boundary
const float DEPTH_DEEP    = 50.0;   // deep ocean zone boundary

// Shore color (used at depth = 0, before transitioning to uniform colors)
const vec3 SHORE_COLOR = vec3(0.3, 0.6, 0.7);

// Shore foam
const float FOAM_SHORE_INTENSITY = 0.6;   // max shore foam opacity
const float FOAM_MAX             = 0.8;   // hard cap on total foam

// Sky reflection
const vec3 SKY_REFLECTION_TINT = vec3(0.45, 0.65, 0.85);
const float SKY_REFLECTION_STRENGTH = 0.35;

// Sun specular (fake directional light)
const vec3 SUN_DIRECTION = vec3(0.3, 0.8, 0.5);
const float SUN_SHININESS = 64.0;
const vec3 SUN_COLOR = vec3(1.0, 0.95, 0.85);
const float SUN_INTENSITY = 0.3;

// Transparency
const float ALPHA_SHORE = 0.45;  // transparency at shoreline
const float ALPHA_DEEP  = 0.95;  // opacity in deep water

// Water color gradient (shallow to deep)
uniform vec3 water_shallow_color : source_color = vec3(0.08, 0.45, 0.65);
uniform vec3 water_mid_color     : source_color = vec3(0.03, 0.2, 0.5);
uniform vec3 water_deep_color    : source_color = vec3(0.01, 0.04, 0.12);
uniform vec3 foam_color          : source_color = vec3(0.85, 0.9, 0.95);

// PBR surface
uniform float roughness : hint_range(0.0, 1.0) = 0.05;
uniform float metallic  : hint_range(0.0, 1.0) = 0.0;

// Wave animation
uniform float wave_speed  : hint_range(0.0, 2.0) = 0.5;
uniform float wave_scale  : hint_range(0.001, 0.1) = 0.02;  // smaller = wider waves
uniform float wave_height : hint_range(0.0, 10.0) = 3.0;    // vertex displacement amplitude

// Fresnel (edge reflection)
uniform float fresnel_power : hint_range(1.0, 10.0) = 3.0;

// Depth buffer for shore detection
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_pos;
varying vec3 world_normal;
varying float cam_dist;

// Compute LOD factors for wave detail layers
// Returns vec2(medium_lod, high_lod), each 0..1 (1 = full detail, 0 = hidden)
vec2 compute_wave_lod(float dist) {
	float lod_med = 1.0 - smoothstep(LOD_MED_START, LOD_MED_END, dist);
	float lod_hi  = 1.0 - smoothstep(LOD_HI_START, LOD_HI_END, dist);
	return vec2(lod_med, lod_hi);
}

// Compute combined wave height from 5 overlapping sine layers
// Each layer has a different frequency and direction to create organic motion
// Returns a value roughly in -1..1 range before being multiplied by wave_height
float compute_wave_height(
	vec3 pos,
	float time,
	vec2 lod
) {
	float s = wave_scale;
	float lod_med = lod.x;
	float lod_hi  = lod.y;

	// Layer 1: broad primary swell (always visible)
	float w1 = sin(pos.x * s * 4.0 + time * 0.7)
	         * cos(pos.z * s * 3.0 + time * 0.5);

	// Layer 2: medium cross-wave (fades at medium distance)
	float w2 = sin(pos.x * s * 7.0 - time * 0.6 + pos.z * s * 5.0)
	         * cos(pos.z * s * 9.0 + time * 0.4);

	// Layer 3: high-frequency chop (nearby only)
	float w3 = sin(pos.x * s * 14.0 + time * 1.3)
	         * sin(pos.z * s * 12.0 - time * 1.1);

	// Layer 4: finest ripples (nearby only)
	float w4 = sin(pos.x * s * 22.0 + time * 1.6)
	         * cos(pos.z * s * 19.0 - time * 1.4);

	// Layer 5: diagonal swell (always visible, breaks up grid alignment)
	float diag = (pos.x * 0.7 + pos.z * 0.7) * s * 5.0;
	float w5 = sin(diag + time * 0.9) * 0.7;

	// Weighted sum: layers 1+5 always; layer 2 at medium range; layers 3+4 close range
	return w1 * 0.35
	     + w5 * 0.2
	     + w2 * 0.25 * lod_med
	     + w3 * 0.12 * lod_hi
	     + w4 * 0.08 * lod_hi;
}

// Compute analytical surface normal from partial derivatives of the wave sum
// This avoids sampling neighboring vertices, we differentiate the sine functions
// directly (d/dx of sin = cos, d/dx of cos = -sin)
vec3 compute_wave_normal(
	vec3 pos,
	float time,
	float height,
	vec2 lod
) {
	float s = wave_scale;
	float lod_med = lod.x;
	float lod_hi  = lod.y;

	// d(wave_height)/dx: partial derivative with respect to X
	float dx = (cos(pos.x * s * 4.0 + time * 0.7) * s * 4.0 * 0.35
	          + cos(pos.x * s * 7.0 - time * 0.6 + pos.z * s * 5.0) * s * 7.0 * 0.25 * lod_med
	          + cos(pos.x * s * 14.0 + time * 1.3) * s * 14.0 * 0.12 * lod_hi) * height;

	// d(wave_height)/dz: partial derivative with respect to Z
	float dz = (-sin(pos.z * s * 3.0 + time * 0.5) * s * 3.0 * 0.35
	           + cos(pos.z * s * 9.0 + time * 0.4) * s * 9.0 * 0.25 * lod_med
	           - cos(pos.z * s * 12.0 - time * 1.1) * s * 12.0 * 0.12 * lod_hi) * height;

	return normalize(vec3(-dx, 1.0, -dz));
}

// Read the depth buffer and compute how deep the terrain is below the water surface
float get_water_depth(vec2 screen_uv, float vertex_z) {
	float screen_depth = texture(depth_texture, screen_uv).r;
	vec4 ndc = vec4(screen_uv * 2.0 - 1.0, screen_depth, 1.0);
	vec4 view_coords = INV_PROJECTION_MATRIX * ndc;
	view_coords.xyz /= view_coords.w;
	return vertex_z - view_coords.z;
}

// Blend water color based on depth zones (shore -> shallow -> mid -> deep)
vec3 get_depth_color(float water_depth) {
	float shore_factor   = smoothstep(0.0, DEPTH_SHORE, water_depth);
	float shallow_factor = smoothstep(DEPTH_SHORE, DEPTH_SHALLOW, water_depth);
	float deep_factor    = smoothstep(DEPTH_SHALLOW, DEPTH_DEEP, water_depth);

	vec3 color = mix(SHORE_COLOR, water_shallow_color, shore_factor);
	color = mix(color, water_mid_color, shallow_factor);
	color = mix(color, water_deep_color, deep_factor);
	return color;
}

// Compute shore foam: animated froth where water meets terrain
float compute_shore_foam(float shore_factor, vec3 pos) {
	float shore_foam = (1.0 - shore_factor) * FOAM_SHORE_INTENSITY;
	float foam_wave = sin(pos.x * 0.3 + TIME * 1.5) * 0.5 + 0.5;
	foam_wave *= sin(pos.z * 0.25 + TIME * 1.2) * 0.5 + 0.5;
	shore_foam *= smoothstep(0.3, 0.7, foam_wave);  // animated foam pattern
	return min(shore_foam, FOAM_MAX);
}

// Fake sun specular highlight (hardcoded light direction)
float compute_sun_specular(vec3 view_dir, vec3 normal) {
	vec3 reflected = reflect(-view_dir, normal);
	return pow(max(dot(reflected, normalize(SUN_DIRECTION)), 0.0), SUN_SHININESS);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float dist = length(world_pos.xz - CAMERA_POSITION_WORLD.xz);
	cam_dist = dist;

	float time = TIME * wave_speed;
	vec2 lod = compute_wave_lod(dist);

	// Compute wave displacement
	float combined = compute_wave_height(world_pos, time, lod);
	float wave_offset = combined * wave_height;

	// Apply vertex displacement
	world_pos.y += wave_offset;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_pos, 1.0)).xyz;

	// Compute analytical normal
	world_normal = compute_wave_normal(world_pos, time, wave_height, lod);
}

void fragment() {
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);

	// Fresnel: edges reflect more (like real water)
	float fresnel = pow(1.0 - max(dot(world_normal, view_dir), 0.0), fresnel_power);

	// Depth-based color
	float water_depth = get_water_depth(SCREEN_UV, VERTEX.z);
	vec3 depth_color = get_depth_color(water_depth);

	// Depth zone factor for foam and alpha
	float shore_factor = smoothstep(0.0, DEPTH_SHORE, water_depth);

	// Shore foam
	float total_foam = compute_shore_foam(shore_factor, world_pos);

	// Compose final color
	vec3 final_color = mix(depth_color, SKY_REFLECTION_TINT, fresnel * SKY_REFLECTION_STRENGTH);
	final_color = mix(final_color, foam_color, total_foam);
	final_color += SUN_COLOR * compute_sun_specular(view_dir, world_normal) * SUN_INTENSITY;

	// Output
	ALBEDO = final_color;
	ROUGHNESS = mix(roughness, 0.4, total_foam);
	METALLIC = metallic;
	NORMAL = world_normal;
	ALPHA = mix(ALPHA_SHORE, ALPHA_DEEP, shore_factor);
}
