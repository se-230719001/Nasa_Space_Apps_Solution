shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx, shadows_disabled;
// Colony dome glass: nearly clear, with a hexagonal frame, a bright fresnel rim
// tinted by the oxygen level, and a grey haze that thickens with CO2, so the
// O2/CO2 trade-off is visible at a glance.

uniform vec3 air_color : source_color = vec3(0.235, 0.86, 0.34);
uniform float haze : hint_range(0.0, 1.0) = 0.0;   // 0 clean air .. 1 very stuffy
uniform float hex_scale = 9.0;

float hex_edge(vec2 p) {
	p *= hex_scale;
	vec2 r = vec2(1.0, 1.7320508);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 q = abs(g);
	float d = max(dot(q, normalize(vec2(1.0, 1.7320508))), q.x);
	return smoothstep(0.44, 0.5, d);
}

void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	float frame = hex_edge(UV * vec2(2.0, 1.0));
	vec3 glass = mix(vec3(0.75, 0.88, 1.0), air_color, 0.35);
	vec3 smog = vec3(0.55, 0.52, 0.48);
	ALBEDO = mix(glass, smog, haze * 0.8);
	EMISSION = air_color * (fres * 0.9 + frame * 0.25);
	ROUGHNESS = mix(0.05, 0.6, haze);
	METALLIC = 0.0;
	ALPHA = clamp(0.04 + fres * 0.35 + frame * 0.18 + haze * 0.28, 0.0, 0.85);
}
