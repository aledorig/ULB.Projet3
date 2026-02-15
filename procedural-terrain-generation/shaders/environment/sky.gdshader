shader_type sky;

uniform vec3 skyColor : source_color = vec3(0.45, 0.72, 0.95);
uniform vec3 horizonColor : source_color = vec3(0.75, 0.85, 0.92);

void sky() {
	float col = clamp(EYEDIR.y / 0.08, 0.0, 1.0);
	vec3 finalColor = mix(horizonColor, skyColor, col);
	COLOR = finalColor;
}
