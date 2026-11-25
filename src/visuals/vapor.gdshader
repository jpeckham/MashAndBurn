shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform int kind = 0; // 0 steam, 1 fictional flame, 2 smoke
void fragment() {
	float h = 1.0 - UV.y;
	float sway = sin(h * 13.0 - TIME * 2.1) * 0.08 * h;
	float width = mix(0.43, 0.06, h);
	float shape = (1.0 - smoothstep(width * 0.45, width, abs(UV.x - 0.5 + sway))) * smoothstep(0.0, 0.13, h) * (1.0 - smoothstep(0.65, 1.0, h));
	float ripples = 0.55 + 0.25 * sin(h * 28.0 - TIME * 3.0 + UV.x * 17.0);
	vec3 tint = kind == 1 ? mix(vec3(1.0, 0.75, 0.16), vec3(0.8, 0.12, 0.025), h) : (kind == 2 ? vec3(0.23, 0.25, 0.27) : vec3(0.83, 0.91, 0.94));
	ALBEDO = tint;
	EMISSION = kind == 1 ? tint * strength * 1.2 : vec3(0.0);
	ALPHA = shape * ripples * strength * (kind == 1 ? 0.9 : 0.45);
}
