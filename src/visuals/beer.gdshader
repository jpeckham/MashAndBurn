shader_type spatial;
render_mode cull_back;
uniform float srm : hint_range(2.0, 50.0) = 10.0;
uniform float haze : hint_range(0.0, 1.0) = 0.15;
void fragment() {
	// Artistic Beer-Lambert RGB bands. No screen sampling or spectral ray tracing.
	float path = 0.65 + 0.6 * (1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))));
	vec3 transmission = exp(-srm * vec3(0.025, 0.11, 0.28) * path);
	vec3 scattering = mix(vec3(0.85, 0.52, 0.14), transmission, 0.55);
	ALBEDO = mix(transmission, scattering, haze * 0.65);
	ROUGHNESS = mix(0.12, 0.5, haze);
	SPECULAR = 0.6;
	ALPHA = clamp(0.36 + (1.0 - dot(transmission, vec3(0.3333))) * 0.5 + haze * 0.32, 0.36, 0.98);
}
