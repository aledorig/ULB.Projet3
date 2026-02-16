shader_type sky;

uniform vec3 skyColor : source_color = vec3(0.3, 0.6, 0.95);
uniform vec3 horizonColor : source_color = vec3(0.65, 0.82, 0.95);

void sky() {
	float col = clamp(EYEDIR.y / 0.08, 0.0, 1.0);
	vec3 finalColor = mix(horizonColor, skyColor, col);
	COLOR = finalColor;
}
