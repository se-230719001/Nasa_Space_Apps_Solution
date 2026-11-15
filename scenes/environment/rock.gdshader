shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Irregular boulders: noise-displaced sphere with a mottled regolith colour.

uniform vec3 rock_color : source_color = vec3(0.4, 0.4, 0.44);
uniform float seed = 0.0;

float h3(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719)) + seed) * 43758.5453); }
float n3(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1,0,0)), f.x), mix(h3(i + vec3(0,1,0)), h3(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h3(i + vec3(0,0,1)), h3(i + vec3(1,0,1)), f.x), mix(h3(i + vec3(0,1,1)), h3(i + vec3(1,1,1)), f.x), f.y), f.z);
}

varying float shade;

void vertex() {
	float d = n3(VERTEX * 1.6) * 0.5 + n3(VERTEX * 3.2) * 0.08;
	VERTEX += NORMAL * (d - 0.3);
	VERTEX.y = max(VERTEX.y, -0.15);
	shade = d;
}

void fragment() {
	ALBEDO = rock_color * (0.75 + shade * 0.6);
	ROUGHNESS = 1.0;
}
