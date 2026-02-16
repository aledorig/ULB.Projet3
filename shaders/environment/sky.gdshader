// =============================================================================
// Procedural Sky: sky/ground gradient with sun discs and animated clouds
// =============================================================================
//
// Auto-converted from Godot's ProceduralSkyMaterial, with added cloud layers.
// Renders a full sky dome with:
//   - Sky gradient (top -> horizon) above the horizon
//   - Ground gradient (bottom -> horizon) below the horizon
//   - Up to 4 sun/moon discs (LIGHT0..LIGHT3) with configurable size + glow
//   - Two noise-based cloud layers scrolling in different directions
//
// UNIFORMS (what to tweak):
//   sky_top_color / sky_horizon_color   -- sky gradient above horizon
//   ground_bottom_color / ground_horizon_color -- ground gradient below horizon
//   inv_sky_curve / inv_ground_curve    -- curve sharpness (higher = sharper)
//   sun_angle_max / inv_sun_curve       -- sun glow halo size and falloff
//   exposure                            -- overall brightness multiplier
//   cloud_texture / cloud_texture2      -- noise textures for cloud layers
//   cloud_dir / cloud_dir2              -- scroll direction per layer
//   cloud_speed / cloud_speed2          -- scroll speed per layer
//   cloud_scale                         -- UV scale of cloud pattern
//   cloud_distance                      -- fade clouds near horizon
// =============================================================================

shader_type sky;
render_mode use_debanding;

const float CLOUD_SPEED_SCALE = 0.01;  // global cloud speed multiplier

// Sky gradient (above horizon)
uniform vec4  sky_top_color     : source_color = vec4(0.385, 0.454, 0.55, 1.0);
uniform vec4  sky_horizon_color : source_color = vec4(0.646, 0.656, 0.67, 1.0);
uniform float inv_sky_curve     : hint_range(1, 100) = 4.0;

// Ground gradient (below horizon)
uniform vec4  ground_bottom_color  : source_color = vec4(0.2, 0.169, 0.133, 1.0);
uniform vec4  ground_horizon_color : source_color = vec4(0.646, 0.656, 0.67, 1.0);
uniform float inv_ground_curve     : hint_range(1, 100) = 30.0;

// Sun/moon disc
uniform float sun_angle_max = 0.877;                       // glow halo outer angle
uniform float inv_sun_curve : hint_range(1, 100) = 22.78;  // glow falloff sharpness
uniform float exposure      : hint_range(0, 128) = 1.0;

// Sky cover (optional overlay texture)
uniform sampler2D sky_cover          : filter_linear, source_color, hint_default_black;
uniform vec4      sky_cover_modulate : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Clouds (two scrolling noise layers)
uniform sampler2D cloud_texture;
uniform sampler2D cloud_texture2;
uniform vec2      cloud_dir;
uniform vec2      cloud_dir2;
uniform vec2      cloud_scale;
uniform float     cloud_distance;
uniform float     cloud_speed;
uniform float     cloud_speed2;

// Apply a single directional light (sun/moon) glow to the sky
// light_dir   : normalized direction of the light
// light_color : color * energy of the light
// light_size  : angular size of the light disc
vec3 apply_light_glow(
	vec3 sky,
	vec3 eye_dir,
	vec3 light_dir,
	vec3 light_color,
	float light_size
) {
	float sun_angle = dot(light_dir, eye_dir);
	float sun_size = cos(light_size);

	if (sun_angle > sun_size) {
		// Inside the sun disc, full light color
		return light_color;
	} else if (sun_angle > sun_angle_max) {
		// In the glow halo, blend toward light color
		float c2 = (sun_size - sun_angle) / (sun_size - sun_angle_max);
		return mix(sky, light_color, clamp(pow(1.0 - c2, inv_sun_curve), 0.0, 1.0));
	}

	return sky;
}

// Compute cloud contribution from two scrolling noise layers
vec3 compute_clouds(vec3 eye_dir) {
	vec2 sky_uv = eye_dir.xz / eye_dir.y;

	vec3 layer1 = texture(cloud_texture,
		sky_uv * cloud_scale + TIME * cloud_dir * cloud_speed * CLOUD_SPEED_SCALE).rgb;
	vec3 layer2 = texture(cloud_texture2,
		sky_uv * cloud_scale + TIME * cloud_dir2 * cloud_speed2 * CLOUD_SPEED_SCALE).rgb;

	// Subtract second layer from first for more organic shapes
	vec3 clouds = layer1 - layer2;

	// Fade clouds near the horizon
	clouds -= smoothstep(0.0, eye_dir.y, cloud_distance);
	return clamp(clouds, vec3(0.0), vec3(1.0));
}


void sky() {
	float v_angle = clamp(EYEDIR.y, -1.0, 1.0);

	// Sky gradient (above horizon)
	vec3 sky = mix(sky_top_color.rgb, sky_horizon_color.rgb,
		clamp(pow(1.0 - v_angle, inv_sky_curve), 0.0, 1.0));

	// Apply up to 4 light sources (sun/moon discs + glow)
	if (LIGHT0_ENABLED) sky = apply_light_glow(sky, EYEDIR, LIGHT0_DIRECTION, LIGHT0_COLOR * LIGHT0_ENERGY, LIGHT0_SIZE);
	if (LIGHT1_ENABLED) sky = apply_light_glow(sky, EYEDIR, LIGHT1_DIRECTION, LIGHT1_COLOR * LIGHT1_ENERGY, LIGHT1_SIZE);
	if (LIGHT2_ENABLED) sky = apply_light_glow(sky, EYEDIR, LIGHT2_DIRECTION, LIGHT2_COLOR * LIGHT2_ENERGY, LIGHT2_SIZE);
	if (LIGHT3_ENABLED) sky = apply_light_glow(sky, EYEDIR, LIGHT3_DIRECTION, LIGHT3_COLOR * LIGHT3_ENERGY, LIGHT3_SIZE);

	// Clouds (only above horizon)
	sky += compute_clouds(EYEDIR);

	// Ground gradient (below horizon)
	vec3 ground = mix(ground_bottom_color.rgb, ground_horizon_color.rgb,
		clamp(pow(1.0 + v_angle, inv_ground_curve), 0.0, 1.0));

	COLOR = mix(ground, sky, step(0.0, EYEDIR.y)) * exposure;
}
