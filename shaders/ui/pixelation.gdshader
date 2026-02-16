// =============================================================================
// Pixelation Post-Process: retro PSX-style downsampling + dithering
// =============================================================================
//
// Applied as a full-screen canvas_item (e.g., on a ColorRect covering the
// viewport). Reduces resolution and color depth for a retro aesthetic.
//
// UNIFORMS (what to tweak):
//   pixel_size      -- size of each "fat pixel" (1 = off, 4 = chunky retro)
//   color_depth     -- number of color levels per channel (4 = very banded, 256 = off)
//   dither_strength -- how much Bayer dithering to apply (0 = none, 1 = heavy)
// =============================================================================

shader_type canvas_item;

uniform int       pixel_size      : hint_range(1, 16) = 2;
uniform int       color_depth     : hint_range(4, 256) = 24;
uniform float     dither_strength : hint_range(0.0, 1.0) = 0.4;
uniform sampler2D screen_texture  : hint_screen_texture, filter_nearest;

// 4x4 Bayer dithering matrix
// adds ordered noise to reduce visible banding
float bayer4(vec2 pos) {
	ivec2 p = ivec2(mod(pos, 4.0));
	int idx = p.y * 4 + p.x;

	float m[16] = float[16](
		 0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		 3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0
	);

	return m[idx] / 16.0;
}

void fragment() {
	// Pixelate by snapping UVs to a lower-res grid
	vec2 screen_size = vec2(textureSize(screen_texture, 0));
	vec2 pixel_count = screen_size / float(pixel_size);
	vec2 snapped_uv = floor(SCREEN_UV * pixel_count) / pixel_count;

	vec4 color = texture(screen_texture, snapped_uv);

	// Reduce color depth with Bayer dithering
	float levels = float(color_depth);
	float dither = bayer4(FRAGCOORD.xy / float(pixel_size)) - 0.5;
	color.rgb += dither * dither_strength / levels;  // add dither noise before quantizing
	color.rgb = floor(color.rgb * levels + 0.5) / levels;  // quantize to N levels

	COLOR = color;
}
