shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Smooth lunar surface: broad rolling terrain, clean bowl-shaped craters with
// soft raised rims, and calm low-frequency tone changes (no fine grain, so the
// ground reads as smooth rather than noisy). Craters fade out on the outpost
// pad so buildings sit on level ground.

uniform vec3 regolith_dark : source_color = vec3(0.34, 0.34, 0.37);
uniform vec3 regolith_light : source_color = vec3(0.56, 0.56, 0.59);
uniform vec3 highland_tint : source_color = vec3(0.62, 0.61, 0.62);
uniform vec3 pad_center = vec3(0.0, 0.0, 0.0);
uniform float pad_radius = 9.0;
uniform float relief = 1.0;
// Play-area framing: the outpost pad reads as a lit, calm "stage"; the land
// beyond it is dimmer with softer crater shading so it recedes.
uniform float pad_brightness = 1.05;
uniform float outer_brightness = 0.75;
uniform float outer_relief = 0.55;
// Width of the soft edge between pad and outer land, and a faint rim line on it.
uniform float pad_edge = 2.5;
uniform vec3 rim_color : source_color = vec3(0.75, 0.8, 1.0);
uniform float rim_strength = 0.18;
// Pad surface: smoothed, compacted regolith with a fine mottled speckle, so
// the play area reads as prepared ground. Deliberately no grid lines: the grid
// look is reserved for placement tiles.
uniform vec3 pad_color : source_color = vec3(0.5, 0.51, 0.6);
uniform float pad_color_mix = 0.35;
uniform float speckle_scale = 2.2;
uniform float speckle_strength = 0.22;
// How much crater relief survives on the pad (0 = perfectly flat).
uniform float pad_crater_keep = 0.35;

varying vec3 world_pos;

vec4 hash42(vec2 p) {
	vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p4 += dot(p4, p4.wzxy + 33.33);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

// Quintic-interpolated value noise: smooth first derivatives, no creases.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash42(i).x, b = hash42(i + vec2(1, 0)).x;
	float c = hash42(i + vec2(0, 1)).x, d = hash42(i + vec2(1, 1)).x;
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm3(vec2 p) {
	return vnoise(p) * 0.57 + vnoise(p * 2.03) * 0.29 + vnoise(p * 4.1) * 0.14;
}

// x: height, y: ejecta brightness, for one crater size.
vec2 craters(vec2 p, float cell, float chance) {
	vec2 g = floor(p / cell);
	vec2 res = vec2(0.0);
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 c = g + vec2(float(x), float(y));
		vec4 h = hash42(c * 1.37 + cell);
		if (h.z > chance) continue;
		vec2 centre = (c + 0.2 + 0.6 * h.xy) * cell;
		float r = cell * (0.2 + 0.25 * h.w);
		float d = length(p - centre) / r;
		if (d > 2.0) continue;
		// Smooth bowl that eases into a rounded rim, then a long gentle falloff.
		float bowl = -(1.0 - smoothstep(0.0, 1.0, d)) * 0.55;
		float rim = exp(-pow((d - 0.95) / 0.32, 2.0)) * 0.22;
		res.x += (bowl + rim) * r * 0.3;
		res.y += smoothstep(2.0, 1.1, d) * smoothstep(0.7, 1.05, d) * 0.35;
	}
	return res;
}

vec2 surface(vec2 p) {
	// Craters are softened on the pad, not removed: a fully flat pad reads
	// like paper and the buildings look like they float on it.
	float pad = mix(pad_crater_keep, 1.0,
		smoothstep(pad_radius, pad_radius + 8.0, length(p - pad_center.xz)));
	vec2 c = craters(p, 7.0, 0.4) + craters(p, 20.0, 0.5) + craters(p, 55.0, 0.55);
	float hills = fbm3(p * 0.025) * 3.0 + fbm3(p * 0.1) * 0.5;
	return vec2(hills * mix(0.3, 1.0, pad) + c.x * pad, c.y * pad);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	// Wide sampling step = smooth, softly shaded normals.
	float e = 0.25;
	vec2 s0 = surface(p);
	float hx = surface(p + vec2(e, 0.0)).x;
	float hz = surface(p + vec2(0.0, e)).x;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float pad_d = length(p - pad_center.xz);
	float outside = smoothstep(pad_radius, pad_radius + pad_edge, pad_d);
	float rim = exp(-pow((pad_d - pad_radius) / 0.35, 2.0)) * rim_strength;
	float k = relief * (1.0 - smoothstep(80.0, 300.0, dist)) * mix(1.0, outer_relief, outside);
	vec3 wn = normalize(vec3(-(hx - s0.x) / e * k, 1.0, -(hz - s0.x) / e * k));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	// Calm, large-scale tone: darker "maria" patches and lighter highlands.
	float tone = fbm3(p * 0.012);
	vec3 col = mix(regolith_dark, regolith_light, smoothstep(0.25, 0.75, tone));
	col = mix(col, highland_tint, smoothstep(0.6, 0.9, fbm3(p * 0.004 + 7.0)) * 0.5);
	col = mix(col, highland_tint * 1.08, clamp(s0.y, 0.0, 0.5));
	float inside = 1.0 - outside;
	col = mix(col, pad_color, pad_color_mix * inside);
	float speckle = vnoise(p * speckle_scale) * 0.6 + vnoise(p * speckle_scale * 3.1) * 0.4;
	col *= 1.0 + (speckle - 0.5) * speckle_strength * inside;
	ALBEDO = col * mix(pad_brightness, outer_brightness, outside) + rim_color * rim;
	ROUGHNESS = 1.0;
}
