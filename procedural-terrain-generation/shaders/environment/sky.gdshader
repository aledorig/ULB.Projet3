shader_type sky;

uniform vec3 skyColor : source_color = vec3(0.38, 0.835, 1.0);
uniform vec3 horizonColor : source_color = vec3(0.631, 0.922, 1.0);

void sky() {
	// Sky gradient
	float col = clamp(EYEDIR.y / 0.08, 0.0, 1.0);
	vec3 finalColor = mix(horizonColor, skyColor, col);
	COLOR = finalColor;
}
