shader_type spatial;
render_mode cull_disabled;

uniform sampler2D noise;
uniform float noiseScale = 20.0;

uniform vec3 wind_direction = vec3(1.0, 0.0, 0.3);
uniform float wind_speed : hint_range(0.0, 5.0) = 1.5;
uniform float wind_strength : hint_range(0.0, 2.0) = 0.4;
uniform float wind_turbulence : hint_range(0.0, 1.0) = 0.3;

varying vec3 worldPos;
varying vec3 grass_tint;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float dist = length(worldPos.xz - CAMERA_POSITION_WORLD.xz);

	float temperature = INSTANCE_CUSTOM.r;
	float moisture = INSTANCE_CUSTOM.g;

	grass_tint = mix(
		vec3(0.7, 0.55, 0.15),   // dry/warm: rich golden
		vec3(0.15, 0.7, 0.05),   // wet: vivid green
		moisture
	);
	grass_tint = mix(
		vec3(0.35, 0.6, 0.3),    // cold: forest green
		grass_tint,
		smoothstep(0.3, 0.6, temperature)
	);

	// flatten blades at distance
	float flatten = smoothstep(80.0, 200.0, dist);
	VERTEX.y *= mix(1.0, 0.15, flatten);

	// blade tip moves most, base stays anchored
	float height_factor = clamp(VERTEX.y * 2.0, 0.0, 1.0);
	height_factor *= height_factor;

	// skip wind for distant blades
	float wind_fade = 1.0 - smoothstep(60.0, 120.0, dist);
	if (wind_fade > 0.01) {
		vec2 wind_dir = normalize(wind_direction.xz);

		float phase = dot(worldPos.xz, wind_dir) * 0.15 + TIME * wind_speed;
		float wind_wave = sin(phase) * 0.5 + 0.5;

		vec3 instance_origin = MODEL_MATRIX[3].xyz;
		float turb_phase = hash(instance_origin.xz) * 6.28 + TIME * wind_speed * 1.3;
		float turbulence = sin(turb_phase) * wind_turbulence;

		float displacement = (wind_wave + turbulence) * wind_strength * height_factor * wind_fade;

		vec3 world_offset = vec3(wind_dir.x * displacement, -abs(displacement) * 0.15, wind_dir.y * displacement);
		vec3 model_offset = (inverse(MODEL_MATRIX) * vec4(world_offset, 0.0)).xyz;
		VERTEX += model_offset;
	}
}

void fragment() {
	vec3 noiseLevel = texture(noise, worldPos.xz / noiseScale).rgb;
	vec3 base_color = grass_tint * 0.40;
	vec3 tip_color = grass_tint * 0.50;
	ALBEDO = mix(base_color, tip_color, 1.0 - UV.y) * mix(vec3(0.8), vec3(0.9), noiseLevel.r);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;

	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
