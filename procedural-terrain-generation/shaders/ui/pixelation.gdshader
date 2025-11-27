shader_type canvas_item;

uniform int pixel_size : hint_range(1, 16) = 3;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

void fragment() {
	vec2 screen_size = vec2(textureSize(screen_texture, 0));
	vec2 pixel_count = screen_size / float(pixel_size);
	
	vec2 snapped_uv = floor(SCREEN_UV * pixel_count) / pixel_count;
	
	COLOR = texture(screen_texture, snapped_uv);
}
