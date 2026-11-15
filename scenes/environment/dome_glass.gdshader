shader_type spatial;
// Colony dome glass: nearly clear when looked at straight on, brighter at the
// grazing edges (fresnel), with a glowing geodesic triangle lattice so it
// reads as a sci-fi structure rather than an invisible bubble.
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled, specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(0.62, 0.86, 1.0);
uniform vec3 lattice_color : source_color = vec3(0.75, 0.92, 1.0);
uniform float base_alpha = 0.035;
uniform float edge_alpha = 0.5;
uniform float lattice_alpha = 0.06;
uniform float cells_around = 24.0;  // triangle columns around the dome
uniform float cells_up = 5.0;  // triangle rows from rim to top
uniform float line_width = 0.018;
// Soft sky reflection band that slides over the glass as the camera moves.
uniform vec3 reflection_color : source_color = vec3(0.85, 0.93, 1.0);
uniform float reflection_alpha = 0.22;

varying vec3 local_dir;

void vertex() {
	local_dir = normalize(VERTEX);
}

void fragment() {
	// Spherical coordinates on the unit dome.
	float azimuth = atan(local_dir.z, local_dir.x) / TAU + 0.5;
	float elevation = asin(clamp(local_dir.y, 0.0, 1.0)) / (PI * 0.5);
	vec2 g = vec2(azimuth * cells_around, elevation * cells_up);
	// Triangle lattice: lines along u, v and u+v.
	float a = abs(fract(g.x) - 0.5);
	float b = abs(fract(g.y) - 0.5);
	float c = abs(fract(g.x + g.y) - 0.5);
	float d = 0.5 - max(max(a, b), c);
	float aa = fwidth(d) * 1.5;
	float line = 1.0 - smoothstep(line_width - aa, line_width + aa, d);
	// Thin the lattice near the cap where meridians bunch up.
	line *= 1.0 - smoothstep(0.85, 1.0, elevation);

	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	vec3 refl = reflect(-VIEW, NORMAL);
	float streak = smoothstep(0.55, 0.75, refl.y) * (1.0 - smoothstep(0.75, 0.95, refl.y));
	ALBEDO = mix(mix(tint, lattice_color, line), reflection_color, streak);
	EMISSION = lattice_color * line * 0.25 + reflection_color * streak * 0.15 + tint * fresnel * 0.12;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	ALPHA = clamp(base_alpha + fresnel * edge_alpha + line * lattice_alpha + streak * reflection_alpha, 0.0, 0.85);
}
