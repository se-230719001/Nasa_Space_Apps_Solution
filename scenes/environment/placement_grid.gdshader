shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Glowing build-placement grid (style guide §12.1): 3x3 cells, bright border,
// soft pulse and a "+" marker in the middle.

uniform vec3 color : source_color = vec3(0.235, 0.86, 0.34);
uniform float cells = 3.0;

void fragment() {
	vec2 uv = UV;
	vec2 g = abs(fract(uv * cells) - 0.5);
	float line = smoothstep(0.47, 0.5, max(g.x, g.y));
	vec2 b = abs(uv - 0.5);
	float border = smoothstep(0.46, 0.5, max(b.x, b.y));
	float plus = (step(abs(b.x), 0.02) * step(abs(b.y), 0.1) + step(abs(b.y), 0.02) * step(abs(b.x), 0.1));
	float pulse = 0.75 + 0.25 * sin(TIME * 3.0);
	float a = (0.12 + line * 0.6 + border * 0.9 + clamp(plus, 0.0, 1.0)) * pulse;
	ALBEDO = color * a;
}
