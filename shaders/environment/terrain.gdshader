// =============================================================================
// Terrain Surface: climate-driven multi-texture blending
// =============================================================================
//
// Blends 11 terrain textures based on altitude, slope, and climate data.
// Climate data (temperature, moisture, continentalness) is passed per-vertex
// through vertex COLOR (R=temp, G=moisture, B=continentalness) by the CPU-side
// TerrainGenerator.
//
// TEXTURE LAYERS (4 base + 7 variants):
//   grass    + grass_dry, grass_lush   -- plains, climate-driven variant
//   sand     + sand_desert             -- beach (low altitude) or desert (hot+dry)
//   rock     + rock_cliff, rock_dark   -- steep slopes or high altitude
//   snow     + snow_chunky, ice        -- above snow line, climate-shifted
//
// UNIFORMS (what to tweak):
//   texture_scale     -- UV tiling density (higher = more repetition per unit)
//   snow_height       -- altitude where snow starts (shifted by temperature)
//   snow_blend_range  -- how gradually snow fades in
//   rock_slope_start  -- slope angle where rock starts appearing
//   rock_slope_end    -- slope angle where rock fully takes over
//   beach_height      -- altitude below which sand appears near coast
//
// VERTEX:  passes world position, height, climate color, and normal to fragment.
// FRAGMENT: decides biome weights from height/slope/climate, picks texture
//           variants within each biome, applies climate tinting.
// =============================================================================

shader_type spatial;

// Transition noise scale and amplitude (breaks up sharp biome boundaries)
const float TRANSITION_NOISE_SCALE = 0.06;  // spatial frequency of boundary noise
const float TRANSITION_NOISE_AMP   = 10.0;  // world-unit jitter on thresholds

// Snow slope limit (snow doesn't stick on steep surfaces)
const float SNOW_SLOPE_MAX = 0.7;  // slope above which snow fades out
const float SNOW_SLOPE_MIN = 0.4;  // slope above which snow is fully gone

// Temperature influence on snow line (higher temp = higher snow line)
const float SNOW_TEMP_SHIFT = 70.0;  // world units of shift per 0.5 temp deviation

// Rock altitude thresholds (where altitude-based rock appears)
const float ROCK_ALT_LOW     = 60.0;   // altitude where rock starts blending in
const float ROCK_ALT_HIGH    = 135.0;  // altitude where rock is at max weight
const float ROCK_ALT_WEIGHT  = 0.7;    // max contribution of altitude-based rock

// Desert climate thresholds
const float DESERT_TEMP_START  = 0.65;
const float DESERT_TEMP_FULL   = 0.8;
const float DESERT_MOIST_START = 0.45;
const float DESERT_MOIST_FULL  = 0.3;

// Rock variant thresholds
const float CLIFF_SLOPE_START   = 0.4;
const float CLIFF_SLOPE_FULL    = 0.7;
const float DARK_ROCK_ALT_START = 100.0;
const float DARK_ROCK_ALT_FULL  = 200.0;

// Snow variant thresholds
const float CHUNKY_SNOW_ALT_START = 200.0;
const float CHUNKY_SNOW_ALT_FULL  = 280.0;
const float ICE_TEMP_START        = 0.4;
const float ICE_TEMP_FULL         = 0.2;
const float ICE_SLOPE_START       = 0.15;
const float ICE_SLOPE_FULL        = 0.05;

// Shore highlight
const float SHORE_GLOW_HIGH     = 9.0;   // altitude where glow starts
const float SHORE_GLOW_LOW      = 1.5;   // altitude where glow peaks
const float SHORE_GLOW_DEPTH    = -3.0;  // depth below which glow fades
const vec3  SHORE_GLOW_COLOR    = vec3(0.85, 0.8, 0.6);
const float SHORE_GLOW_STRENGTH = 0.4;

// Underwater tint
const float UNDERWATER_MAX_DEPTH = 90.0;   // depth for max darkening
const float UNDERWATER_MAX_FACTOR = 0.8;   // maximum tint strength
const float UNDERWATER_BLEND = 0.85;
const vec3 UNDERWATER_SHALLOW = vec3(0.55, 0.7, 0.5);
const vec3 UNDERWATER_DEEP    = vec3(0.05, 0.15, 0.35);

// Climate tint colors
const vec3 TINT_HOT_DRY    = vec3(0.7, 0.55, 0.15);    // rich golden
const vec3 TINT_HOT_WET    = vec3(0.15, 0.7, 0.05);    // vivid green
const vec3 TINT_COLD_DRY   = vec3(0.45, 0.42, 0.35);   // gray-brown tundra
const vec3 TINT_COLD_WET   = vec3(0.25, 0.5, 0.25);    // muted boreal green
const vec3 TINT_SAND       = vec3(0.95, 0.85, 0.45);   // warm yellow
const vec3 TINT_ROCK       = vec3(0.5, 0.45, 0.4);     // gray-brown
const vec3 TINT_SNOW       = vec3(0.95, 0.97, 1.0);    // cool white

// Texture-tint mixing ratio
const float TINT_STRENGTH  = 0.45;  // how much tint affects texture color
const float TEXTURE_MIX    = 0.75;  // 0.75 = mostly textured, 0.25 = tint only

// Base textures (4 biome types)
uniform sampler2D grass_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_texture  : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_texture  : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_texture  : source_color, filter_linear_mipmap, repeat_enable;

// Texture variants (7 climate/slope sub-types)
uniform sampler2D grass_dry_texture   : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_lush_texture  : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_desert_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_cliff_texture  : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_dark_texture   : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_chunky_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D ice_texture         : source_color, filter_linear_mipmap, repeat_enable;

// Biome threshold controls (exposed as uniforms for in-editor tweaking)
uniform float texture_scale    : hint_range(1.0, 100.0) = 20.0;
uniform float snow_height      : hint_range(20.0, 400.0) = 180.0;
uniform float snow_blend_range : hint_range(5.0, 80.0) = 45.0;
uniform float rock_slope_start : hint_range(0.1, 0.9) = 0.55;
uniform float rock_slope_end   : hint_range(0.1, 0.9) = 0.35;
uniform float beach_height     : hint_range(0.0, 20.0) = 9.0;

varying vec3  climate_data;    // R=temperature, G=moisture, B=continentalness
varying vec3  world_pos;
varying vec3  world_normal;
varying float terrain_height;

// Simple hash for pseudo-random noise
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Value noise: smooth pseudo-random variation used to break up biome edges
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);  // smoothstep interpolation

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Compute the 4 biome weights: grass, sand, rock, snow
// Returns vec4(grass_w, sand_w, rock_w, snow_w) normalized to sum to 1
vec4 compute_biome_weights(
	float h,
	float slope,
	float temperature,
	float moisture,
	float continentalness,
	float noise
) {
	// Snow: above snow line, shifted by temperature
	float eff_snow = snow_height + (temperature - 0.5) * SNOW_TEMP_SHIFT + noise;
	float snow_w = smoothstep(eff_snow, eff_snow + snow_blend_range, h);
	snow_w *= smoothstep(SNOW_SLOPE_MAX, SNOW_SLOPE_MIN, slope);

	// Rock: steep slopes OR high altitude
	float slope_rock = smoothstep(rock_slope_end, rock_slope_start, slope);
	float alt_rock = smoothstep(ROCK_ALT_LOW + noise, ROCK_ALT_HIGH + noise, h) * ROCK_ALT_WEIGHT;
	float rock_w = max(slope_rock, alt_rock) * (1.0 - snow_w);

	// Sand: beach near sea level OR hot+dry desert
	float beach_sand = smoothstep(beach_height + noise * 0.3, -1.0, h)
	                 * smoothstep(0.3, 0.5, continentalness);
	float desert_sand = smoothstep(DESERT_TEMP_START, DESERT_TEMP_FULL, temperature)
	                  * smoothstep(DESERT_MOIST_START, DESERT_MOIST_FULL, moisture)
	                  * smoothstep(0.4, 0.5, continentalness);
	float sand_w = max(beach_sand, desert_sand) * (1.0 - snow_w) * (1.0 - slope_rock);

	// Grass: everything else
	float grass_w = max(1.0 - snow_w - rock_w - sand_w, 0.0);

	// Normalize
	float total = max(grass_w + sand_w + rock_w + snow_w, 0.001);
	return vec4(grass_w, sand_w, rock_w, snow_w) / total;
}


// Grass: pick between base, dry (hot+dry), and lush (cool+wet) variants
vec3 sample_grass(
	vec2 uv,
	float temperature,
	float moisture
) {
	vec3 base = texture(grass_texture, uv).rgb;
	vec3 dry  = texture(grass_dry_texture, uv).rgb;
	vec3 lush = texture(grass_lush_texture, uv).rgb;

	float dry_factor  = smoothstep(0.4, 0.55, temperature) * smoothstep(0.55, 0.3, moisture);
	float lush_factor = smoothstep(0.55, 0.3, temperature) * smoothstep(0.35, 0.6, moisture);
	float base_factor = max(1.0 - dry_factor - lush_factor, 0.0);

	return base * base_factor + dry * dry_factor + lush * lush_factor;
}

// Sand: pick between beach sand and desert dunes
vec3 sample_sand(
	vec2 uv,
	float temperature,
	float moisture
) {
	vec3 base   = texture(sand_texture, uv).rgb;
	vec3 desert = texture(sand_desert_texture, uv).rgb;

	float dune_factor = smoothstep(0.55, 0.7, temperature) * smoothstep(0.55, 0.3, moisture);
	return mix(base, desert, dune_factor);
}

// Rock: pick between base, dark (high altitude), and cliff (steep slopes)
vec3 sample_rock(
	vec2 uv,
	float h,
	float slope
) {
	vec3 base  = texture(rock_texture, uv).rgb;
	vec3 cliff = texture(rock_cliff_texture, uv).rgb;
	vec3 dark  = texture(rock_dark_texture, uv).rgb;

	float cliff_factor = smoothstep(CLIFF_SLOPE_START, CLIFF_SLOPE_FULL, slope);
	float dark_factor  = smoothstep(DARK_ROCK_ALT_START, DARK_ROCK_ALT_FULL, h) * (1.0 - cliff_factor);

	return mix(mix(base, dark, dark_factor), cliff, cliff_factor);
}

// Snow: pick between base snow, chunky (high peaks), and ice (cold flat)
vec3 sample_snow(
	vec2 uv,
	float h,
	float slope,
	float temperature
) {
	vec3 base   = texture(snow_texture, uv).rgb;
	vec3 chunky = texture(snow_chunky_texture, uv).rgb;
	vec3 ice    = texture(ice_texture, uv).rgb;

	float chunky_factor = smoothstep(CHUNKY_SNOW_ALT_START, CHUNKY_SNOW_ALT_FULL, h);
	float ice_factor = smoothstep(ICE_TEMP_START, ICE_TEMP_FULL, temperature)
	                 * smoothstep(ICE_SLOPE_START, ICE_SLOPE_FULL, slope)
	                 * (1.0 - chunky_factor);

	return mix(mix(base, chunky, chunky_factor), ice, ice_factor);
}

// Compute climate-driven tint color for blending with textures
vec3 compute_climate_tint(
	vec4 weights,
	float temperature,
	float moisture
) {
	// Grass tint varies with temperature and moisture
	vec3 warm_tint  = mix(TINT_HOT_DRY, TINT_HOT_WET, moisture);
	vec3 cold_tint  = mix(TINT_COLD_DRY, TINT_COLD_WET, moisture);
	vec3 grass_tint = mix(cold_tint, warm_tint, smoothstep(0.3, 0.6, temperature));

	return grass_tint * weights.x   // grass
	     + TINT_SAND  * weights.y   // sand
	     + TINT_ROCK  * weights.z   // rock
	     + TINT_SNOW  * weights.w;  // snow
}

// Apply shore highlight and underwater tint to the final color
vec3 apply_shore_and_underwater(vec3 color, float h) {
	// Shore highlight: bright strip at water's edge
	float shore_glow = smoothstep(SHORE_GLOW_HIGH, SHORE_GLOW_LOW, h)
	                 * smoothstep(SHORE_GLOW_DEPTH, SHORE_GLOW_LOW, h);
	color = mix(color, SHORE_GLOW_COLOR, shore_glow * SHORE_GLOW_STRENGTH);

	// Underwater tint: darken terrain below water level
	if (h < 0.0) {
		float depth_factor = clamp(-h / UNDERWATER_MAX_DEPTH, 0.0, UNDERWATER_MAX_FACTOR);
		vec3 underwater_color = mix(UNDERWATER_SHALLOW, UNDERWATER_DEEP, depth_factor);
		color = mix(color, underwater_color, depth_factor * UNDERWATER_BLEND);
	}

	return color;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_height = world_pos.y;
	climate_data = COLOR.rgb;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float temperature    = climate_data.r;
	float moisture       = climate_data.g;
	float continentalness = climate_data.b;

	float h     = terrain_height;
	float slope = 1.0 - normalize(world_normal).y;  // 0=flat, 1=vertical cliff

	// Boundary noise to prevent sharp horizontal biome edges
	float noise = (value_noise(world_pos.xz * TRANSITION_NOISE_SCALE) - 0.5) * TRANSITION_NOISE_AMP;

	vec2 uv = world_pos.xz / texture_scale;

	// Step 1: biome weights
	vec4 weights = compute_biome_weights(h, slope, temperature, moisture, continentalness, noise);

	// Step 2: sample texture variants per biome
	vec3 grass_s = sample_grass(uv, temperature, moisture);
	vec3 sand_s  = sample_sand(uv, temperature, moisture);
	vec3 rock_s  = sample_rock(uv, h, slope);
	vec3 snow_s  = sample_snow(uv, h, slope, temperature);

	// Step 3: weighted texture blend
	vec3 tex_blend = grass_s * weights.x + sand_s * weights.y
	               + rock_s * weights.z  + snow_s * weights.w;

	// Step 4: climate tinting
	vec3 tint = compute_climate_tint(weights, temperature, moisture);
	vec3 tinted_tex = tex_blend * mix(vec3(1.0), tint, TINT_STRENGTH);
	vec3 final_color = mix(tint, tinted_tex, TEXTURE_MIX);

	// Step 5: shore and underwater effects
	final_color = apply_shore_and_underwater(final_color, h);

	// Output
	ALBEDO = final_color;
	ROUGHNESS = mix(0.9, 1.0, weights.z);  // rock is slightly rougher
	METALLIC = 0.0;
	AO = 1.0;
	AO_LIGHT_AFFECT = 0.5;
}
