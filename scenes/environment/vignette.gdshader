shader_type canvas_item;
// Soft screen-edge darkening that pulls the eye toward the outpost.

uniform vec4 tint : source_color = vec4(0.02, 0.03, 0.1, 1.0);
uniform float strength = 0.35;
// Where the darkening starts (0 = centre, 1 = corner).
uniform float inner = 0.55;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	uv.x *= 0.85;
	float d = length(uv) / 1.31;
	COLOR = vec4(tint.rgb, smoothstep(inner, 1.0, d) * strength);
}
