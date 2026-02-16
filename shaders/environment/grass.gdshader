// =============================================================================
// Grass Blades: wind-animated billboard grass via MultiMesh instancing
// =============================================================================
//
// Renders individual grass blades as alpha-cutout quads placed by MultiMesh.
// Each blade is colored by climate data (temperature + moisture)
// using the same tint palette as the terrain shader.
//
// UNIFORMS (what to tweak):
//   grass_texture / grass_texture_2 -- blade alpha masks (2 shape variants)
//   wind_direction                  -- XZ direction wind blows
//   wind_speed                      -- animation speed of wind waves
//   wind_strength                   -- how far blades bend in wind
//   wind_turbulence                 -- random per-blade jitter (gustiness)
//
// INSTANCE_CUSTOM: r=temperature, g=moisture, b=texture variant (0 or 1).
//
// VERTEX:  flattens distant blades (LOD), animates wind sway on blade tips.
// FRAGMENT: alpha-tests the blade shape, samples ground color, darkens base.
// =============================================================================

shader_type spatial;
render_mode cull_disabled, depth_draw_never;

// Distance LOD: flatten blades at distance (cheaper than removing them)
const float LOD_FLATTEN_START = 80.0;   // distance where flattening begins
const float LOD_FLATTEN_END   = 200.0;  // distance where blades are fully flat
const float LOD_FLATTEN_MIN   = 0.15;   // minimum height scale (not zero to avoid pop-in)

// Wind LOD: skip wind animation for distant blades
const float WIND_FADE_START  = 60.0;
const float WIND_FADE_END    = 120.0;
const float WIND_PHASE_SCALE = 0.15;   // spatial frequency of global wind wave
const float WIND_TURB_SPEED  = 1.3;    // turbulence time multiplier vs wind_speed
const float WIND_DROOP       = 0.15;   // how much blades droop downward when bent

// Edge-on discard threshold (dot product of normal vs view)
const float EDGE_ON_THRESHOLD = 0.15;

// Blade gradient (darken base, lighten tip)
const float BLADE_BASE_BRIGHTNESS = 0.7;  // darkest at base
const float BLADE_TIP_BRIGHTNESS  = 1.0;  // brightest at tip

// Climate tint palette
// MUST MATCH TERRAIN SHADER CONSTS!!!!!
const vec3 TINT_HOT_DRY  = vec3(0.7, 0.55, 0.15);    // rich golden
const vec3 TINT_HOT_WET  = vec3(0.15, 0.7, 0.05);    // vivid green
const vec3 TINT_COLD_DRY = vec3(0.45, 0.42, 0.35);   // gray-brown tundra
const vec3 TINT_COLD_WET = vec3(0.25, 0.5, 0.25);    // muted boreal green

// Blade shape textures (alpha masks)
uniform sampler2D grass_texture   : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D grass_texture_2 : source_color, filter_linear_mipmap, repeat_disable;

// Wind animation
uniform vec3  wind_direction  = vec3(1.0, 0.0, 0.3);
uniform float wind_speed      : hint_range(0.0, 5.0) = 1.5;
uniform float wind_strength   : hint_range(0.0, 2.0) = 0.4;
uniform float wind_turbulence : hint_range(0.0, 1.0) = 0.3;

varying vec3  world_pos;
varying float tex_variant;  // 0 or 1, selects grass_texture vs grass_texture_2
varying vec2  climate;      // r=temperature, g=moisture from INSTANCE_CUSTOM

// Simple hash for pseudo-random noise
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Compute wind displacement for a grass blade vertex
// height_factor: 0 at base, 1 at tip (controls how much this vertex moves)
// instance_origin: world-space origin of this grass instance (MODEL_MATRIX[3].xyz)
// Returns world-space offset vector
vec3 compute_wind(
	vec3 pos,
	float height_factor,
	float dist,
	vec3 instance_origin
) {
	float wind_fade = 1.0 - smoothstep(WIND_FADE_START, WIND_FADE_END, dist);
	if (wind_fade < 0.01) return vec3(0.0);

	vec2 wind_dir = normalize(wind_direction.xz);

	// Global wind wave (all blades sway together in a sine pattern)
	float phase = dot(pos.xz, wind_dir) * WIND_PHASE_SCALE + TIME * wind_speed;
	float wind_wave = sin(phase) * 0.5 + 0.5;

	// Per-blade turbulence (random phase offset per instance)
	float turb_phase = hash(instance_origin.xz) * 6.28 + TIME * wind_speed * WIND_TURB_SPEED;
	float turb = sin(turb_phase) * wind_turbulence;

	float displacement = (wind_wave + turb) * wind_strength * height_factor * wind_fade;

	// Blades droop slightly downward when bent
	return vec3(wind_dir.x * displacement, -abs(displacement) * WIND_DROOP, wind_dir.y * displacement);
}


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float dist = length(world_pos.xz - CAMERA_POSITION_WORLD.xz);

	tex_variant = INSTANCE_CUSTOM.b;
	climate = INSTANCE_CUSTOM.rg;

	// Distance LOD: flatten blades
	float flatten = smoothstep(LOD_FLATTEN_START, LOD_FLATTEN_END, dist);
	VERTEX.y *= mix(1.0, LOD_FLATTEN_MIN, flatten);

	// Wind displacement (only blade tips, base stays anchored)
	float height_factor = clamp(VERTEX.y * 2.0, 0.0, 1.0);
	height_factor *= height_factor;  // quadratic: tip moves much more than middle

	vec3 wind_offset = compute_wind(world_pos, height_factor, dist, MODEL_MATRIX[3].xyz);
	vec3 model_offset = (inverse(MODEL_MATRIX) * vec4(wind_offset, 0.0)).xyz;
	VERTEX += model_offset;
}

void fragment() {
	// Discard edge-on blades (saves fill rate, barely visible anyway)
	float facing = abs(dot(normalize(NORMAL), VIEW));
	if (facing < EDGE_ON_THRESHOLD) discard;

	// Alpha test: pick texture variant and cut out blade shape
	float alpha_1 = texture(grass_texture, UV).a;
	float alpha_2 = texture(grass_texture_2, UV).a;
	float grass_alpha = mix(alpha_1, alpha_2, step(0.5, tex_variant));
	ALPHA = grass_alpha;
	ALPHA_SCISSOR_THRESHOLD = 0.5;

	// Color: climate-driven tint
	float temperature = climate.x;
	float moisture    = climate.y;
	vec3 warm_tint  = mix(TINT_HOT_DRY, TINT_HOT_WET, moisture);
	vec3 cold_tint  = mix(TINT_COLD_DRY, TINT_COLD_WET, moisture);
	vec3 ground_color = mix(cold_tint, warm_tint, smoothstep(0.3, 0.6, temperature));

	// Darken blade base (UV.y=0 is base, UV.y=1 is tip)
	float blade_gradient = mix(BLADE_BASE_BRIGHTNESS, BLADE_TIP_BRIGHTNESS, 1.0 - UV.y);
	ALBEDO = ground_color * blade_gradient;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;

	// Flip normal for back faces (cull_disabled means both sides render)
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
