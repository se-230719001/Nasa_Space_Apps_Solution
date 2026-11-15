shader_type spatial;
// Toon outline (inverted hull). Used as a material next_pass: back faces are
// pushed out along their normals and drawn in a flat colour behind the mesh.
// The push scales with view depth, so the line keeps the same on-screen width
// at any zoom level.
render_mode unshaded, cull_front, skip_vertex_transform;

uniform vec4 outline_color : source_color = vec4(0.043, 0.071, 0.212, 1.0);
// Line width as a fraction of view depth (~0.005 = about 3 px at 720p).
uniform float width = 0.005;

void vertex() {
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// Directional shadow maps use an orthographic projection: don't inflate
	// there, or the outline would fatten (and jag) the cast shadows.
	bool shadow_pass = PROJECTION_MATRIX[3][3] == 1.0;
	if (!shadow_pass) {
		v.xyz += n * width * -v.z;
	}
	VERTEX = v.xyz;
	NORMAL = n;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
