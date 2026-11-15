shader_type spatial;
// Soft "contact shadow" blob laid flat under a building so it sits on the
// ground instead of floating. Rounded-rectangle falloff fits round and boxy
// footprints alike.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 shadow_color : source_color = vec4(0.043, 0.071, 0.212, 1.0);
uniform float strength = 0.8;
// Footprint edge as a fraction of the plane's half-size: full strength inside,
// fading to nothing at the plane's edge.
uniform float inner = 0.7;

void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float d = pow(pow(p.x, 4.0) + pow(p.y, 4.0), 0.25);
	float a = 1.0 - smoothstep(inner, 1.0, d);
	ALBEDO = shadow_color.rgb;
	ALPHA = strength * a;
}
