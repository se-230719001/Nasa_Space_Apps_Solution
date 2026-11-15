shader_type spatial;
// Toon outline for the noise-displaced boulders: repeats rock.gdshader's
// displacement first so the hull hugs the rock, then inflates like outline.gdshader.
render_mode unshaded, cull_front, skip_vertex_transform;

uniform vec4 outline_color : source_color = vec4(0.043, 0.071, 0.212, 1.0);
uniform float width = 0.005;
uniform float seed = 0.0;

float h3(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719)) + seed) * 43758.5453); }
float n3(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1,0,0)), f.x), mix(h3(i + vec3(0,1,0)), h3(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h3(i + vec3(0,0,1)), h3(i + vec3(1,0,1)), f.x), mix(h3(i + vec3(0,1,1)), h3(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	vec3 p = VERTEX;
	float d = n3(p * 1.6) * 0.5 + n3(p * 3.2) * 0.08;
	p += NORMAL * (d - 0.3);
	p.y = max(p.y, -0.15);
	vec4 v = MODELVIEW_MATRIX * vec4(p, 1.0);
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	if (PROJECTION_MATRIX[3][3] != 1.0) {
		v.xyz += n * width * -v.z;
	}
	VERTEX = v.xyz;
	NORMAL = n;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
